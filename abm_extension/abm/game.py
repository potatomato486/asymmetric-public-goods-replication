"""Verified game rules (SI Table S15), with explicit extended fairness utility."""
from dataclasses import dataclass
import numpy as np


@dataclass(frozen=True)
class Game:
    kind: str
    treatment: str
    endowments: tuple
    productivities: tuple
    threshold: float | None = None
    reward: float | None = None

    def __post_init__(self):
        e, p = np.asarray(self.endowments), np.asarray(self.productivities)
        if self.kind not in ('linear', 'threshold'):
            raise ValueError('Unknown game kind')
        if e.ndim != 1 or len(e) < 2 or p.shape != e.shape:
            raise ValueError('Invalid agent roster')
        if not np.isfinite(e).all() or not np.isfinite(p).all():
            raise ValueError('Nonfinite game parameter')
        if np.any(e <= 0) or np.any(e != np.floor(e)) or np.any(p <= 0):
            raise ValueError('Positive integer endowments and positive productivity required')
        if self.kind == 'threshold':
            if self.threshold is None or self.reward is None:
                raise ValueError('Verified threshold and reward must be explicit')
            if not np.isfinite([self.threshold, self.reward]).all() or min(self.threshold, self.reward) <= 0:
                raise ValueError('Invalid threshold parameters')
        elif self.threshold is not None or self.reward is not None:
            raise ValueError('Linear game has no fixed threshold/reward')


def get_game(kind, treatment):
    """Direct transcription of supplement Table S15, not dyadic extrapolation."""
    if treatment not in ('FE', 'AI', 'MI'):
        raise ValueError('Unknown treatment')
    e = (24, 24, 24, 24) if treatment == 'FE' else (36, 36, 12, 12)
    if kind == 'linear':
        p = {'FE': (3.2,)*4, 'AI': (3.8,3.8,2.6,2.6), 'MI': (2.6,2.6,3.8,3.8)}[treatment]
        return Game(kind, treatment, e, p)
    if kind == 'threshold':
        p = {'FE': (1,)*4, 'AI': (3,3,1,1), 'MI': (1,1,3,3)}[treatment]
        theta = {'FE': 48, 'AI': 120, 'MI': 72}[treatment]
        return Game(kind, treatment, e, p, theta, 20)
    raise ValueError('Unknown game kind')


def validate_actions(actions, game):
    c = np.asarray(actions)
    if c.ndim < 1 or c.shape[-1] != len(game.endowments):
        raise ValueError('Agent count mismatch')
    if not np.isfinite(c).all() or np.any(c != np.floor(c)):
        raise ValueError('Contributions must be finite integers')
    if np.any(c < 0) or np.any(c > np.asarray(game.endowments)):
        raise ValueError('Contribution outside endowment bounds')
    return c


def outcomes(actions, game, beta=0., gamma=0.):
    """Return monetary and behavioral quantities for (..., agent) actions.

    Fairness is mean pairwise disagreement with others (extension assumption).
    All values, including experimental outcomes, use this one verified engine.
    """
    c = validate_actions(actions, game).astype(float)
    if not np.isfinite([beta, gamma]).all() or min(beta, gamma) < 0:
        raise ValueError('Invalid preference weights')
    e, p = np.asarray(game.endowments), np.asarray(game.productivities)
    n = len(e)
    effective = c*p
    collective = effective.sum(axis=-1)
    success = collective >= game.threshold if game.kind == 'threshold' else np.full(collective.shape, np.nan)
    reward = collective/n if game.kind == 'linear' else game.reward*success
    payoff = e-c+reward[..., None]
    relative = c/e
    absolute_gap = np.abs(c[..., :, None]-c[..., None, :]).sum(axis=-1)/((n-1)*e.max())
    relative_gap = np.abs(relative[..., :, None]-relative[..., None, :]).sum(axis=-1)/(n-1)
    utility = payoff-beta*absolute_gap-gamma*relative_gap
    total_payoff = payoff.sum(axis=-1)
    dispersion = np.abs(payoff[..., :, None]-payoff[..., None, :]).sum(axis=(-2, -1))
    gini = np.divide(dispersion, 2*n*total_payoff, out=np.zeros_like(dispersion), where=total_payoff>0)
    result = dict(relative_contribution=relative, effective_contribution=effective,
                  collective_contribution=collective, reward=reward, payoff=payoff,
                  absolute_gap=absolute_gap, relative_gap=relative_gap, utility=utility,
                  group_relative_contribution=c.sum(axis=-1)/e.sum(),
                  surplus=(total_payoff-e.sum())/e.sum(), gini=gini, success=success)
    if not np.isfinite(utility).all() or np.any(payoff < 0):
        raise AssertionError('Impossible payoff or utility')
    return result
