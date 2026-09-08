# 用户逐步核对清单

代码由代理完成并运行；这不等于你已能独立解释、修改或 debug。以下掌握度均为“尚未核验”。一次只处理一个模块。

1. **Game engine** (`abm/game.py`)：先手算 AI linear 在 (36,36,12,12) 时总有效贡献 336、每人 reward 84；再手算 threshold AI 在 (18,18,6,6) 与 (17,18,6,6) 时的差别。解释 endowment 每轮重置，以及 reward 与 monetary payoff 的区别。
2. **Signal / strategy** (`abm/strategies.py`)：用一个不等 endowment 的例子，分别计算其他三人的 mean(c/e)、sum(c)/sum(e)、sum(p*c)。解释为什么本 MVP 选择的第一个量不代表论文已经确认的人类认知机制。自己改一个 lookup entry 并预测下一轮输出。
3. **Simultaneous update** (`abm/simulation.py`, `episode`)：画出上一轮与本轮两个状态，解释为何改变四人的遍历顺序不该改变输出。读负面对照测试，看故意按顺序立即更新如何改变结果。
4. **Fairness / introspection**：解释 Eq.4 的两项惩罚及四人平均两两差异的假设；算一例 utility。区分“固定其他人的策略”和“固定其他人的行动”，并说明为何反事实必须重新跑四人的整段 episode。
5. **Monte Carlo / uncertainty**：区分 round、revision、snapshot、seed。解释为什么不能把 614,400 条 agent-round 输出当成 614,400 个独立样本；说明 95% Monte Carlo interval 不包含模型假设的不确定性。
6. **Research interpretation**：从 `output/comparison.csv` 和敏感性表解释模型在哪些 treatment 失败、为什么初始化依赖阻止稳态结论、怎样预先规定下一次诊断而不按四人结果反复调参。

第一次学习只做第 1 项。下一步的掌握证据应是你独立算对一例并修改一项测试；不要先背整套代码。

申请表述目前最多到：有一个代理协助构建、通过规则验证、已运行多 seed 并发现迁移偏差的计算扩展；独立编写和理解程度仍需以上核对。不能声称已经复现作者的四人 ABM、完成稳态估计或验证了因果机制。
