"""Decode the two pinned author MATLAB tables and audit before computing outcomes.

This is intentionally a file-specific MCOS decoder, not a general MATLAB-table
reader. It checks the deposited MD5, internal field names, sizes and all rows
of the existing linear CSV before using the same structure for threshold data.
"""
import hashlib
import io
import json
from pathlib import Path
import sys
import numpy as np
import pandas as pd

ROOT=Path(__file__).resolve().parent
if (ROOT/'.deps').exists():
    sys.path.insert(0,str(ROOT/'.deps'))
from scipy.io import loadmat
from scipy.io.matlab import _mio5
from abm.game import get_game, outcomes

FIELDS=['Treatment','Session','GroupID','PlayerID','GlobalPlayerID','Round','Contribution']
GROUP=['Treatment','Session','GroupID']
KEY=GROUP+['PlayerID','Round']


def decode_author_table(path, expected_rows):
    record=json.loads((ROOT/'reference/zenodo_record.json').read_text(encoding='utf-8'))
    file_record=next(f for f in record['files'] if f['key']==path.name)
    assert 'md5:'+hashlib.md5(path.read_bytes()).hexdigest()==file_record['checksum']
    d=loadmat(path)
    assert str(d['all_data']['_Class'][0])=='table'
    raw=d['__function_workspace__'].tobytes()
    assert raw[:8]==b'\x00\x01IM\x00\x00\x00\x00'
    stream=io.BytesIO(raw)
    reader=_mio5.MatFile5Reader(stream,byte_order='<')
    reader.initialize_read();stream.seek(8)
    header,_=reader.read_var_header()
    decoded=reader.read_var_array(header,process=True)
    metadata=decoded['MCOS'][0,0]['_ObjectMetadata'][0]
    assert metadata.shape==(11,1)
    assert metadata[4,0].item()==expected_rows and metadata[6,0].item()==7
    names=[str(x.item()) for x in metadata[7,0].flat]
    assert names==FIELDS
    columns=metadata[2,0]
    assert columns.shape==(1,7)
    values={}
    for name,column in zip(names,columns.flat):
        assert column.shape==(expected_rows,1)
        if name=='Treatment':
            values[name]=[str(x.item()) for x in column.flat]
        else:
            assert np.isfinite(column).all() and np.equal(column,np.floor(column)).all()
            values[name]=column.reshape(-1).astype(int)
    return pd.DataFrame(values)


def validate_raw(data,kind):
    n=12480 if kind=='linear' else 11040
    expected_groups={'FE':50,'AI':52,'MI':54} if kind=='linear' else {'FE':38,'AI':50,'MI':50}
    assert data.shape==(n,7) and list(data.columns)==FIELDS
    assert not data.isna().any().any() and not data.duplicated(KEY).any()
    assert set(data.Treatment)=={'FE','AI','MI'}
    assert set(data.Session)=={1,2} and set(data.PlayerID)=={1,2,3,4}
    for _,part in data.groupby(GROUP+['PlayerID']):
        assert len(part)==20 and set(part.Round)==set(range(1,21))
    for _,part in data.groupby(GROUP+['Round']):
        assert len(part)==4 and set(part.PlayerID)=={1,2,3,4}
    for _,part in data.groupby(GROUP+['PlayerID']):
        assert part.GlobalPlayerID.nunique()==1
    roster=data[GROUP+['PlayerID','GlobalPlayerID']].drop_duplicates()
    assert not roster.duplicated(['Treatment','GlobalPlayerID']).any()
    groups=data[GROUP].drop_duplicates()
    assert groups.groupby('Treatment').size().to_dict()==expected_groups
    for treatment,count in expected_groups.items():
        for session in (1,2):
            assert len(groups[(groups.Treatment==treatment)&(groups.Session==session)])==count//2
    return dict(input_rows=n,input_columns=7,missing_cells=0,duplicate_observation_keys=0,
                group_sessions=len(groups),participant_session_ids=len(roster),
                pooled_group_id_unique=not groups.GroupID.duplicated().any(),
                excluded_rows=0,exclusion_reason='none; exactly the supplied first-20-round dataset',
                group_key=GROUP,observation_key=KEY,
                group_sessions_by_treatment=expected_groups,
                participant_identity_across_sessions='not reconstructible from GlobalPlayerID; IDs change by session')


def compute_groups(data,kind):
    parts=[]
    for treatment in ('FE','AI','MI'):
        part=data[data.Treatment==treatment].sort_values(GROUP+['Round','PlayerID'])
        assert len(part)%4==0
        actions=part.Contribution.to_numpy().reshape(-1,4)
        game=get_game(kind,treatment)
        m=outcomes(actions,game)
        identifiers=part[GROUP+['Round']].iloc[::4].reset_index(drop=True)
        assert not identifiers.duplicated(GROUP+['Round']).any()
        for metric in ('group_relative_contribution','surplus','gini','success'):
            identifiers[metric]=m[metric]
        identifiers['game']=kind
        parts.append(identifiers)
    result=pd.concat(parts,ignore_index=True)
    assert len(result)*4==len(data)
    return result


def main():
    import argparse
    parser=argparse.ArgumentParser()
    parser.add_argument('--existing-linear',type=Path,default=Path('C:/Users/GU/Documents/GitHub/asymmetric-public-goods-replication/data/LinearPGG_4P_ExperimentalData.csv'))
    args=parser.parse_args()
    audit={}; all_groups=[]
    for kind in ('linear','threshold'):
        filename=f'{kind.capitalize()}PGG_4P_ExperimentalData.mat'
        source=ROOT/'reference'/filename
        d=decode_author_table(source,12480 if kind=='linear' else 11040)
        audit[kind]=validate_raw(d,kind)
        if kind=='linear':
            if args.existing_linear.exists():
                original=pd.read_csv(args.existing_linear)
                pd.testing.assert_frame_equal(d,original,check_dtype=False)
                audit[kind]['existing_csv_cellwise_equal']=True
                audit[kind]['existing_csv_sha256']=hashlib.sha256(args.existing_linear.read_bytes()).hexdigest()
                audit[kind]['existing_csv_path']=str(args.existing_linear)
            else:
                raise FileNotFoundError('Provide the existing project CSV for required independent decoder cross-check')
        raw=ROOT/'data/raw'/f'{kind}_experimental.csv'
        text=d.to_csv(index=False).encode('utf-8')
        if raw.exists():
            assert raw.read_bytes()==text, 'Refuse to overwrite changed raw copy'
        else:
            raw.write_bytes(text)
        audit[kind]['source_mat_sha256']=hashlib.sha256(source.read_bytes()).hexdigest()
        audit[kind]['converted_csv_sha256']=hashlib.sha256(text).hexdigest()
        g=compute_groups(d,kind);all_groups.append(g)
        audit[kind]['output_group_round_rows']=len(g)
        audit[kind]['output_group_round_columns']=len(g.columns)
    groups=pd.concat(all_groups,ignore_index=True)
    metrics=['group_relative_contribution','surplus','gini','success']
    sessions=groups.groupby(['game']+GROUP,as_index=False)[metrics].mean()
    # Published rounded benchmark checks establish column mappings and units.
    lin=sessions[sessions.game=='linear'].groupby('Treatment')[metrics].mean()
    thr=sessions[sessions.game=='threshold'].groupby('Treatment')[metrics].mean()
    for treatment,rc,surplus in [('FE',.633,1.39),('AI',.670,1.66),('MI',.673,1.30)]:
        assert abs(lin.loc[treatment,'group_relative_contribution']-rc)<.0006
        assert abs(lin.loc[treatment,'surplus']-surplus)<.006
    for treatment,success,surplus in [('FE',.900,.267),('AI',.480,.052),('MI',.588,.124)]:
        assert abs(thr.loc[treatment,'success']-success)<.0006
        assert abs(thr.loc[treatment,'surplus']-surplus)<.0006
    audit['published_benchmarks']='all six means checked against SI pp16,18; tolerance reflects rounding'
    groups.to_csv(ROOT/'data/processed/experimental_group_round.csv',index=False,float_format='%.12g')
    sessions.to_csv(ROOT/'data/processed/experimental_group_session.csv',index=False,float_format='%.12g')
    (ROOT/'output/data_audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
    print(json.dumps(audit,indent=2))
    print(sessions.groupby(['game','Treatment'])[metrics].mean().round(5).to_string())


if __name__=='__main__':
    main()
