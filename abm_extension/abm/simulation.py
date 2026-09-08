"""Synchronous game episodes and asynchronous introspection strategy revisions."""
from dataclasses import dataclass, asdict
import numpy as np
from .game import outcomes
from .strategies import draw_profile, next_actions, validate_profiles


@dataclass(frozen=True)
class Config:
    steps: int = 6000
    burn_in: int = 2000
    thin: int = 100
    rounds: int = 20
    levels: int = 13
    beta: float = 0.
    gamma: float = 14.
    selection: float = 1.
    initial: str = 'random'
    signal: str = 'mean'
    diagnostic_every: int = 250

    def __post_init__(self):
        for key in ('steps', 'burn_in', 'thin', 'rounds', 'levels', 'diagnostic_every'):
            if not isinstance(getattr(self, key), int):
                raise ValueError('Integer simulation controls required')
        if not 0 <= self.burn_in < self.steps or min(self.thin,self.rounds,self.diagnostic_every)<1 or self.levels<2:
            raise ValueError('Invalid simulation controls')
        if (self.steps-self.burn_in)//self.thin < 1:
            raise ValueError('No retained samples')
        if not np.isfinite([self.beta,self.gamma,self.selection]).all() or min(self.beta,self.gamma,self.selection)<0:
            raise ValueError('Invalid preference/selection parameters')
        if self.initial not in ('random','zero','full') or self.signal not in ('mean','minimum'):
            raise ValueError('Invalid initialization/signal')


def episode(profiles, game, config, order=None):
    """Evaluate a full counterfactual from its own initial actions, for all players."""
    validate_profiles(profiles, game.endowments, config.levels)
    batch, n = profiles.shape[:2]
    actions = np.empty((batch, config.rounds, n), dtype=int)
    actions[:,0,:] = profiles[:,:,0]
    for r in range(1, config.rounds):
        actions[:,r,:] = next_actions(profiles, actions[:,r-1,:], game.endowments,
                                     config.levels, config.signal, order)
    measures = outcomes(actions, game, config.beta, config.gamma)
    return actions, measures['utility'].mean(axis=1)


def switching_probability(delta, selection):
    """Numerically stable logistic, including neutral and extreme selection."""
    d = np.asarray(delta, dtype=float)
    if not np.isfinite(d).all() or not np.isfinite(selection) or selection<0:
        raise ValueError('Invalid utility difference/selection')
    # Saturation beyond +/-700 is numerically exact at double precision.
    if selection == 0:
        return np.full(d.shape, .5)
    bounded = np.clip(d, -700/selection, 700/selection)*selection
    z = np.exp(-np.abs(bounded))
    return np.where(bounded>=0, 1/(1+z), z/(1+z))


def run_chains(game, config, seeds):
    """Batch independent chains while keeping an independent RNG per seed.

    Batching is an optimization only; each chain has exactly the same output
    when run alone. Returned snapshots are post-revision resident episodes.
    """
    if len(seeds)<1 or len(set(seeds)) != len(seeds):
        raise ValueError('Distinct seeds required')
    rngs = [np.random.default_rng(seed) for seed in seeds]
    profiles = np.stack([draw_profile(rng, game.endowments, config.levels, config.initial) for rng in rngs])
    initial_profiles = profiles.copy()
    actions, utilities = episode(profiles, game, config)
    batch, n = profiles.shape[:2]
    rows = np.arange(batch)
    kept_actions, kept_steps, diagnostics, blocks = [], [], [], []
    accepted_total = np.zeros(batch, dtype=int)
    chosen_counts = np.zeros((batch, n), dtype=int)
    window_sum = np.zeros((batch,4))
    window_n = 0
    # Metrics for every resident profile are accumulated without thinning.
    retained_sum = np.zeros((batch,4))
    retained_n = 0
    for step in range(1, config.steps+1):
        candidates = profiles.copy()
        focal = np.empty(batch,dtype=int)
        draws = np.empty(batch)
        for b, rng in enumerate(rngs):
            i = int(rng.integers(n)); focal[b] = i
            candidate = rng.integers(0,game.endowments[i]+1,size=config.levels+1)
            while np.array_equal(candidate,profiles[b,i]):
                candidate = rng.integers(0,game.endowments[i]+1,size=config.levels+1)
            candidates[b,i] = candidate
            draws[b] = rng.random()
        alt_actions, alt_utilities = episode(candidates,game,config)
        probability = switching_probability(alt_utilities[rows,focal]-utilities[rows,focal],config.selection)
        accepted = draws < probability
        profiles[accepted] = candidates[accepted]
        actions[accepted] = alt_actions[accepted]
        utilities[accepted] = alt_utilities[accepted]
        accepted_total += accepted
        chosen_counts[rows,focal] += 1
        m = outcomes(actions,game,config.beta,config.gamma)
        metrics = np.column_stack([m['group_relative_contribution'].mean(axis=1), m['surplus'].mean(axis=1),
                                   m['gini'].mean(axis=1), m['success'].mean(axis=1)])
        window_sum += metrics; window_n += 1
        if step>config.burn_in:
            retained_sum += metrics; retained_n += 1
        if step % config.diagnostic_every == 0 or step == config.steps:
            for b, seed in enumerate(seeds):
                blocks.append(dict(seed=int(seed),step=step,window_steps=window_n,
                                   group_relative_contribution=window_sum[b,0]/window_n,
                                   surplus=window_sum[b,1]/window_n,gini=window_sum[b,2]/window_n,
                                   success=window_sum[b,3]/window_n,
                                   acceptance_rate=accepted_total[b]/step))
            window_sum[:]=0;window_n=0
        if step>config.burn_in and (step-config.burn_in)%config.thin==0:
            kept_steps.append(step);kept_actions.append(actions.copy())
    validate_profiles(profiles,game.endowments,config.levels)
    assert np.all(chosen_counts.sum(axis=1)==config.steps)
    for b,seed in enumerate(seeds):
        diagnostics.append(dict(seed=int(seed),acceptance_rate=accepted_total[b]/config.steps,
                                **{f'agent_{i+1}_revisions':int(chosen_counts[b,i]) for i in range(n)},
                                group_relative_contribution=retained_sum[b,0]/retained_n,
                                surplus=retained_sum[b,1]/retained_n,gini=retained_sum[b,2]/retained_n,
                                success=retained_sum[b,3]/retained_n))
    return dict(actions=np.stack(kept_actions,axis=1),steps=kept_steps,seeds=seeds,
                profiles=profiles,initial_profiles=initial_profiles,diagnostics=diagnostics,
                blocks=blocks,config=asdict(config))
