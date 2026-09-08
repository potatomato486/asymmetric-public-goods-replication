"""Verification checks against independent arithmetic and an independent scalar schedule."""
import itertools
import unittest
from dataclasses import replace
import numpy as np
from abm.game import Game, get_game, outcomes
from abm.strategies import draw_profile, signal_indices, next_actions
from abm.simulation import Config, episode, run_chains, switching_probability


class GameTests(unittest.TestCase):
    def test_published_table(self):
        expected = {'FE':(48,(1,1,1,1)), 'AI':(120,(3,3,1,1)), 'MI':(72,(1,1,3,3))}
        for treatment,(theta,p) in expected.items():
            g=get_game('threshold',treatment)
            self.assertEqual((g.threshold,g.reward,g.productivities),(theta,20,p))
            self.assertEqual(sum(g.endowments),96)

    def test_linear_known_cases(self):
        for treatment,total,surplus in [('FE',307.2,2.2),('AI',336,2.5),('MI',278.4,1.9)]:
            g=get_game('linear',treatment)
            m=outcomes(g.endowments,g)
            np.testing.assert_allclose(m['payoff'],[total/4]*4)
            self.assertAlmostEqual(float(m['surplus']),surplus)
            self.assertAlmostEqual(float(m['gini']),0)
            z=outcomes([0]*4,g)
            np.testing.assert_array_equal(z['payoff'],g.endowments)
            self.assertEqual(z['surplus'],0)
        g=get_game('linear','AI');m=outcomes([36,0,0,0],g)
        np.testing.assert_allclose(m['payoff'],[34.2,70.2,46.2,46.2])

    def test_threshold_equality_and_one_unit_below(self):
        for treatment in ('FE','AI','MI'):
            g=get_game('threshold',treatment)
            half=np.array(g.endowments)//2
            m=outcomes(half,g)
            self.assertEqual(m['collective_contribution'],g.threshold)
            self.assertTrue(m['success']); self.assertEqual(m['reward'],20)
            below=half.copy();below[0]-=1
            self.assertFalse(outcomes(below,g)['success'])
            self.assertEqual(outcomes(below,g)['reward'],0)
            self.assertFalse(outcomes([0]*4,g)['success'])
            self.assertTrue(outcomes(g.endowments,g)['success'])
            self.assertAlmostEqual(float(outcomes(g.endowments,g)['surplus']),-1/6)

    def test_fairness_matches_dyadic_equation_four(self):
        g=Game('linear','dyadic',(36,12),(1.9,1.3))
        m=outcomes([18,12],g,beta=18,gamma=94)
        penalty=18*6/36+94*.5
        np.testing.assert_allclose(m['utility'],m['payoff']-penalty)

    def test_pairwise_fairness_not_deviation_from_mean(self):
        g=get_game('linear','FE');m=outcomes([12,0,12,24],g,beta=0,gamma=1)
        self.assertAlmostEqual(m['relative_gap'][0],1/3)
        self.assertAlmostEqual(m['relative_gap'][1],2/3)

    def test_independent_scalar_payoff_oracle(self):
        rng=np.random.default_rng(17)
        for kind,treatment in itertools.product(('linear','threshold'),('FE','AI','MI')):
            g=get_game(kind,treatment)
            for _ in range(60):
                c=[int(rng.integers(e+1)) for e in g.endowments]
                total=sum(p*x for p,x in zip(g.productivities,c))
                reward=total/4 if kind=='linear' else 20*int(total>=g.threshold)
                pay=[e-x+reward for e,x in zip(g.endowments,c)]
                utility=[]
                for i in range(4):
                    ag=sum(abs(c[i]-c[j]) for j in range(4) if j!=i)/(3*max(g.endowments))
                    rg=sum(abs(c[i]/g.endowments[i]-c[j]/g.endowments[j]) for j in range(4) if j!=i)/3
                    utility.append(pay[i]-18*ag-94*rg)
                m=outcomes(c,g,18,94)
                np.testing.assert_allclose(m['payoff'],pay)
                np.testing.assert_allclose(m['utility'],utility)
                self.assertAlmostEqual(float(m['surplus']),(4*reward-sum(c))/96)
                self.assertTrue(0<=m['gini']<=.75+1e-12)

    def test_invalid_states_rejected(self):
        g=get_game('linear','FE')
        for c in ([0,0,0],[-1,0,0,0],[25,0,0,0],[.5,0,0,0],[np.nan]*4,[np.inf]*4):
            with self.assertRaises(ValueError): outcomes(c,g)
        for kwargs in (dict(beta=-1),dict(gamma=np.nan)):
            with self.assertRaises(ValueError): outcomes([0]*4,g,**kwargs)
        with self.assertRaises(ValueError): Game('threshold','unknown',(24,)*4,(1,)*4)
        with self.assertRaises(ValueError): get_game('linear','typo')


class ScheduleTests(unittest.TestCase):
    def setUp(self):
        self.game=get_game('linear','AI')
        self.config=Config(steps=30,burn_in=10,thin=5,diagnostic_every=10)
        self.profile=draw_profile(np.random.default_rng(9),self.game.endowments,13)[None,:,:]

    def test_signal_definition_extremes_and_tie(self):
        np.testing.assert_array_equal(signal_indices([[18,18,6,6]],self.game.endowments),[[6]*4])
        np.testing.assert_array_equal(signal_indices([[0]*4],self.game.endowments),[[0]*4])
        np.testing.assert_array_equal(signal_indices([self.game.endowments],self.game.endowments),[[12]*4])
        # Others' relative mean for focal 0 is (0+0+0.125)/3 = 1/24; ties round up.
        self.assertEqual(signal_indices([[0,0,0,3]],(24,)*4)[0,0],1)

    def test_all_iteration_orders_same(self):
        base=episode(self.profile,self.game,self.config)[0]
        for order in itertools.permutations(range(4)):
            np.testing.assert_array_equal(episode(self.profile,self.game,self.config,order)[0],base)

    def test_independent_scalar_episode_oracle(self):
        s=self.profile[0];e=self.game.endowments
        history=[s[:,0].tolist()]
        for _ in range(1,20):
            prev=history[-1]
            nxt=[]
            for i in range(4):
                q=sum(prev[j]/e[j] for j in range(4) if j!=i)/3
                index=int(np.floor(q*12+.5+1e-12))
                nxt.append(int(s[i,index+1]))
            history.append(nxt)
        np.testing.assert_array_equal(episode(self.profile,self.game,self.config)[0][0],history)

    def test_sequential_negative_control_differs(self):
        # Detect that the test would fail if decisions accidentally observed current-round choices.
        s=np.zeros((1,4,14),dtype=int)
        s[0,:,0]=[0,0,0,24]
        s[0,:,1:]=np.arange(13)[None,:]*2
        g=get_game('linear','FE')
        old=s[:,:,0].copy()
        correct=next_actions(s,old,g.endowments)
        wrong=old.copy()
        for i in range(4):
            wrong[:,i]=next_actions(s,wrong,g.endowments)[:,i]
        self.assertFalse(np.array_equal(correct,wrong))

    def test_agent_relabeling_invariance(self):
        perm=np.array([3,1,0,2]);g=self.game
        permuted=Game(g.kind,g.treatment,tuple(np.array(g.endowments)[perm]),tuple(np.array(g.productivities)[perm]))
        c,u=episode(self.profile,g,self.config)
        pc,pu=episode(self.profile[:,perm,:],permuted,self.config)
        np.testing.assert_array_equal(pc,c[:,:,perm]);np.testing.assert_allclose(pu,u[:,perm])

    def test_counterfactual_recomputes_others(self):
        g=get_game('linear','FE');s=np.zeros((1,4,14),dtype=int)
        s[0,:,1:]=np.arange(13)[None,:]*2
        original=episode(s,g,self.config)[0]
        candidate=s.copy();candidate[0,0,:]=24
        counter=episode(candidate,g,self.config)[0]
        self.assertTrue(np.any(counter[0,1:,1:]!=original[0,1:,1:]))
        np.testing.assert_array_equal(s[:,:,0],[[0]*4])

    def test_seed_reproducibility_and_batch_independence(self):
        first=run_chains(self.game,self.config,[1,2])
        again=run_chains(self.game,self.config,[1,2])
        alone=run_chains(self.game,self.config,[1])
        for key in ('actions','profiles','initial_profiles'):
            np.testing.assert_array_equal(first[key],again[key])
            np.testing.assert_array_equal(first[key][:1],alone[key])
        self.assertEqual(first['actions'].shape,(2,4,20,4))
        self.assertEqual(first['steps'],[15,20,25,30])
        self.assertFalse(np.array_equal(first['initial_profiles'][0],first['initial_profiles'][1]))
        for row in first['diagnostics']:
            self.assertEqual(sum(row[f'agent_{i}_revisions'] for i in range(1,5)),30)

    def test_probability_extremes(self):
        np.testing.assert_allclose(switching_probability([-1e300,0,1e300],100),[0,.5,1],atol=1e-300)
        np.testing.assert_array_equal(switching_probability([-99,0,99],0),[.5]*3)
        for d in (1.,5.,12.):
            self.assertAlmostEqual(float(switching_probability(d,1)+switching_probability(-d,1)),1)

    def test_complete_chain_against_scalar_reference(self):
        # Independently evaluate all actions/utilities and commit/reject complete profiles.
        import math
        g=get_game('threshold','AI')
        cfg=replace(self.config,beta=18,gamma=94)
        rng=np.random.default_rng(73)
        s=draw_profile(rng,g.endowments,cfg.levels)
        def scalar(profile):
            history=[profile[:,0].tolist()]
            for _ in range(1,20):
                previous=history[-1]
                chosen=[]
                for i in range(4):
                    q=sum(previous[j]/g.endowments[j] for j in range(4) if i!=j)/3
                    chosen.append(int(profile[i,int(math.floor(q*12+.5+1e-12))+1]))
                history.append(chosen)
            utility=[0.]*4
            for c in history:
                reward=20*int(sum(x*p for x,p in zip(c,g.productivities))>=120)
                for i in range(4):
                    absolute=sum(abs(c[i]-c[j]) for j in range(4) if i!=j)/(3*36)
                    relative=sum(abs(c[i]/g.endowments[i]-c[j]/g.endowments[j]) for j in range(4) if i!=j)/3
                    utility[i]+=(g.endowments[i]-c[i]+reward-18*absolute-94*relative)/20
            return np.array(history),utility
        actions,u=scalar(s);snapshots=[]
        for step in range(1,31):
            i=int(rng.integers(4))
            v=rng.integers(0,g.endowments[i]+1,size=14)
            while np.array_equal(v,s[i]):
                v=rng.integers(0,g.endowments[i]+1,size=14)
            coin=rng.random();alternative=s.copy();alternative[i]=v
            candidate,altu=scalar(alternative)
            probability=1/(1+math.exp(-(altu[i]-u[i])))
            if coin<probability:
                s,actions,u=alternative,candidate,altu
            if step>10 and (step-10)%5==0:
                snapshots.append(actions.copy())
        optimized=run_chains(g,cfg,[73])
        np.testing.assert_array_equal(optimized['profiles'][0],s)
        np.testing.assert_array_equal(optimized['actions'][0],np.stack(snapshots))

    def test_initial_and_parameter_extremes(self):
        for initial in ('zero','full'):
            c=replace(self.config,initial=initial,beta=0,gamma=0,selection=0)
            result=run_chains(self.game,c,[11])
            self.assertEqual(result['actions'].shape[-1],4)
        with self.assertRaises(ValueError): Config(steps=10,burn_in=10)
        with self.assertRaises(ValueError): Config(levels=1)
        with self.assertRaises(ValueError): run_chains(self.game,self.config,[1,1])


if __name__=='__main__':
    unittest.main(verbosity=2)
