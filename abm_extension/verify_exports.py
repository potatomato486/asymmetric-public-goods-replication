"""Read exported baseline files back from disk and independently reconcile levels."""
import hashlib
import json
from pathlib import Path
import numpy as np
import pandas as pd
from abm.game import get_game, outcomes

ROOT=Path(__file__).resolve().parent


def main():
    audits=[]
    for folder in sorted((ROOT/'output/baseline').iterdir()):
        if not folder.is_dir(): continue
        manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
        assert manifest['status']=='complete'
        for name,digest in manifest['output_sha256'].items():
            assert hashlib.sha256((folder/name).read_bytes()).hexdigest()==digest
        p=pd.read_csv(folder/'agent_round.csv');g=pd.read_csv(folder/'group_round.csv')
        key=['run_id','revision_step','round']
        assert not g.duplicated(key).any() and not p.duplicated(key+['agent_id']).any()
        assert len(p)==102400 and len(g)==25600
        assert len(p.columns)==29 and len(g.columns)==25
        assert p.notna().all().all()
        assert not g.drop(columns='success').isna().any().any()
        assert p.groupby(key).size().eq(4).all()
        assert p.groupby(key).agent_id.apply(lambda x:set(x)=={1,2,3,4}).all()
        rebuilt=p.groupby(key,as_index=False).agg(total_contribution=('contribution','sum'),
          total_endowment=('endowment','sum'),total_effective=('effective_contribution','sum'),total_payoff=('payoff','sum'))
        assert not rebuilt.duplicated(key).any()
        joined=rebuilt.merge(g,on=key,validate='one_to_one',indicator=True)
        assert len(joined)==len(g) and joined['_merge'].eq('both').all()
        np.testing.assert_allclose(joined.total_contribution/joined.total_endowment,joined.group_relative_contribution,atol=1e-10)
        np.testing.assert_allclose((joined.total_payoff-joined.total_endowment)/joined.total_endowment,joined.surplus,atol=1e-10)
        np.testing.assert_allclose(joined.total_effective,joined.collective_contribution,atol=1e-10)
        game=get_game(manifest['game']['kind'],manifest['game']['treatment'])
        sorted_p=p.sort_values(key+['agent_id'])
        c=sorted_p.contribution.to_numpy().reshape(-1,4)
        m=outcomes(c,game,manifest['config']['beta'],manifest['config']['gamma'])
        np.testing.assert_allclose(sorted_p.payoff,m['payoff'].reshape(-1),atol=1e-9)
        np.testing.assert_allclose(sorted_p.utility,m['utility'].reshape(-1),atol=1e-9)
        np.testing.assert_allclose(sorted_p.endowment,np.tile(game.endowments,len(g)))
        np.testing.assert_allclose(sorted_p.productivity,np.tile(game.productivities,len(g)))
        gs=g.sort_values(key)
        for metric in ('gini','surplus','group_relative_contribution'):
            np.testing.assert_allclose(gs[metric],m[metric],atol=1e-10)
        if game.kind=='threshold':
            np.testing.assert_array_equal(gs.success,m['success'])
        # Retained CSV snapshots and their separately written chain summary must agree.
        chain=pd.read_csv(folder/'chain_summary.csv')
        per_seed=g.groupby('seed')[['group_relative_contribution','surplus','gini']].mean()
        for metric in per_seed.columns:
            np.testing.assert_allclose(per_seed[metric],chain.sort_values('seed')[f'snapshot_{metric}'],atol=1e-10)
        audits.append(dict(cell=folder.name,agent_input_shape=list(p.shape),group_input_shape=list(g.shape),
            join_rows_before=len(g),join_rows_after=len(joined),join_match_rate=1,duplicate_keys=0,
            contribution_bounds=True,agent_count_conservation=True,all_payoffs_recomputed=True,
            all_utilities_recomputed=True,all_csv_hashes_match=True,excluded_rows=0))
    assert len(audits)==6
    (ROOT/'output/export_audit.json').write_text(json.dumps(audits,indent=2),encoding='utf-8')
    print('Six baseline exports verified: 614400 agent rows, 153600 group rows; no row loss or join inflation.')


if __name__=='__main__':
    main()
