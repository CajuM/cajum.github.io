---
title: Finite State Machines and Lessons on Control
date: 2025-10-09
---

How ought we define intelligence? Is it the capacity to find complex solutions? Is it measured in the amount of truth one knows?
If we go for the former definition, intelligence becomes detached from reality. If we go for the later, it becomes as plastic as a truth table. However, we know that as a minimum intelligence must be anchored in reality to be useful.

We may ask ourselves when is a man intelligent? And who can answer this question? His peers? His superiors? What if he has none? What if his peers are just as intelligent but in disjoint domains?

Let us draw a parallel with Finite State Machines. We have a minimum definition of intelligence by which to judge a FSM's intelligence. It is a truth table. Therefore we can judge the intelligence of a FSM by analogy of a string being a sentence and whether it will accept the string or not as the truth value of that sentence.

Now, we may ask ourselves, given a set of FSMs of n states, how do we build another FSM that judges the smartest FSMs? We could ask each FSM every sentence in its language, but that would take forever. Thankfully there is a shortcut. We can encode each FSM as a symbol which will make the judge FSM transition into either the state corresponding to the smartest or to the alternative state. As a note, FSMs can be equivalent, so there can be multiple FSMs that accept the same language.

One last question remains, how smart should the judge FSM be? Given that there are 2**(n**2) possible FSMs to be judged. The number of subsets by inserting or removing transitions. This gives us our lower bound for the judge FSMs, which relies on the premise that it knows a priori the smartest FSMs.

Going back to the human question, by analogy, we may be tempted to conclude that it is impossible for a human to judge the intelligence of the entire species. However, our conclusion above was that we may not judge the intelligence of all FSMs with n states through a FSM with comparable complexity, not a particular subset of them. Indeed, in the case of humanity we need only judge 8 billion possible encephala out of uncountably many configurations of synapses. Thus, with apriori knowledge only 8 billion transitions would be required, about the size of the memory of a modern laptop. However, given that human intelligence is organized such that abilities at various tasks correlate, some tests(IQ) can accurately predict intelligence, or at least its scarcity. Although, IQ tests begin to loose accuracy at over 160 points.

It is still worth pondering weather eugenics is a feasible undertaking. If we indeed lack the capacity to describe traits we should select for or a goal to evolve towards, it may lead to disaster. Because we may not be able to judge the ideal human by intelligence, health, etc.

Another example of this phenomenon is economics, take communism, on paper ideal centralized control of the market. In reality, that control is worse than the natural balance that occurs in a free market.
