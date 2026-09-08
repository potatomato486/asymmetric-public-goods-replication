"""Run prespecified simulations and export auditable, R-readable CSV files."""
import argparse
from dataclasses import asdict, replace
import hashlib
import json
from pathlib import Path
import platform
import time
import numpy as np
import pandas as pd
from abm.game import get_game, outcomes
from abm.simulation import Config, run_chains

ROOT=Path(__file__).resolve().parent


def checksum(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def export_result(result, game, config, experiment, out):
    """Export one row per run x retained step x round x agent, plus group rows."""
    a=result['actions']; batch,samples,rounds,n=a.shape
    m=outcomes(a,game,config.beta,config.gamma)
    common=dict(experiment=experiment,game=game.kind,treatment=game.treatment,**asdict(config))
    seeds=np.asarray(result['seeds'])
    run_ids=np.array([f'{experiment}_{game.kind}_{game.treatment}_{s}' for s in seeds])
    base=dict(run_id=np.repeat(run_ids,samples*rounds),seed=np.repeat(seeds,samples*rounds),
              group_id=np.repeat(np.arange(1,batch+1),samples*rounds),
              revision_step=np.tile(np.repeat(result['steps'],rounds),batch),
              round=np.tile(np.arange(1,rounds+1),batch*samples))
    group=pd.DataFrame(base).assign(**common)
    for key in ('collective_contribution','group_relative_contribution','surplus','gini','success','reward'):
        group[key]=m[key].reshape(-1)
    assert len(group)==batch*samples*rounds
    assert not group.duplicated(['run_id','revision_step','round']).any()
    group.to_csv(out/'group_round.csv',index=False,float_format='%.12g')
    player=group[['run_id','seed','group_id','revision_step','round']].loc[group.index.repeat(n)].reset_index(drop=True)
    player=player.assign(**common)
    player['agent_id']=np.tile(np.arange(1,n+1),len(group))
    player['endowment']=np.tile(game.endowments,len(group))
    player['productivity']=np.tile(game.productivities,len(group))
    player['contribution']=a.reshape(-1)
    for key in ('relative_contribution','effective_contribution','payoff','utility','absolute_gap','relative_gap'):
        player[key]=m[key].reshape(-1)
    assert len(player)==len(group)*n
    assert not player.duplicated(['run_id','revision_step','round','agent_id']).any()
    assert player.notna().all().all()
    player.to_csv(out/'agent_round.csv',index=False,float_format='%.12g')
    summary=pd.DataFrame(result['diagnostics']).assign(**common)
    summary['run_id']=run_ids
    summary['retained_profiles']=samples
    summary['post_burn_profiles']=config.steps-config.burn_in
    for key in ('group_relative_contribution','surplus','gini','success'):
        summary[f'snapshot_{key}']=m[key].mean(axis=(1,2))
    summary.to_csv(out/'chain_summary.csv',index=False,float_format='%.12g')
    pd.DataFrame(result['blocks']).assign(**common).to_csv(out/'learning_blocks.csv',index=False,float_format='%.12g')
    np.savez_compressed(out/'strategies.npz',initial=result['initial_profiles'],final=result['profiles'],seeds=seeds)
    return dict(agent_rows=len(player),group_rows=len(group),chains=len(summary),
                excluded_burn_in_profiles_per_chain=config.burn_in,
                snapshot_sampling='every thin revisions after burn-in; chain_summary uses ALL post-burn profiles',
                no_deleted_or_filtered_agent_observations=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--suite',choices=['baseline','sensitivity'],default='baseline')
    parser.add_argument('--only',choices=['resolution25','minimum_signal','initial_zero','initial_full','longer','no_fairness'])
    args=parser.parse_args()
    variants={'baseline':{}} if args.suite=='baseline' else {
        'resolution25':dict(levels=25), 'minimum_signal':dict(signal='minimum'),
        'initial_zero':dict(initial='zero'),'initial_full':dict(initial='full'),
        'longer':dict(steps=12000,burn_in=8000), 'no_fairness':dict(beta=0,gamma=0)}
    if args.only:
        variants={args.only:variants[args.only]}
    for name,changes in variants.items():
        chains=32 if name=='baseline' else 16
        for gi,kind in enumerate(('linear','threshold')):
            for ti,treatment in enumerate(('FE','AI','MI')):
                game=get_game(kind,treatment)
                cfg=Config(beta=0 if kind=='linear' else 18,gamma=14 if kind=='linear' else 94)
                cfg=replace(cfg,**changes)
                seeds=[2026090700+gi*10000+ti*100+i for i in range(chains)]
                out=ROOT/'output'/name/f'{kind}_{treatment}';out.mkdir(parents=True,exist_ok=True)
                manifest=dict(status='running',experiment=name,game=asdict(game),config=asdict(cfg),seeds=seeds,
                              python=platform.python_version(),numpy=np.__version__,pandas=pd.__version__,
                              platform=platform.platform(),seed_generator='numpy default_rng PCG64',
                              source_hashes={str(p.relative_to(ROOT)):checksum(p) for p in sorted((ROOT/'abm').glob('*.py'))},
                              parameter_source='SI Table S15 p14; dyadic learning optima SI p13',
                              estimation='no four-player calibration; finite-chain transfer diagnostic')
                (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
                print(f'RUN {name} {kind} {treatment}: {chains} chains x {cfg.steps} revisions',flush=True)
                start=time.perf_counter()
                result=run_chains(game,cfg,seeds)
                audit=export_result(result,game,cfg,name,out)
                manifest.update(status='complete',seconds=time.perf_counter()-start,audit=audit,
                                output_sha256={p.name:checksum(p) for p in sorted(out.glob('*.csv'))})
                (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
                means=pd.DataFrame(result['diagnostics'])[['group_relative_contribution','surplus','success']].mean().round(4).to_dict()
                print(f'DONE {name} {kind} {treatment}: {manifest["seconds"]:.1f}s; {means}',flush=True)


if __name__=='__main__':
    main()
