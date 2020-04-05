# Differentially Private OPF

This repository contains supplementary materials for the paper __Differentially Private Optimal Power Flow for Distribution Grids__ by V. Dvorkin, F. Fioretto, P. Van Hentenryck, J. Kazempour, and P. Pinson.

The proof of Theorem 2 is contained in [Appendix.pdf](https://github.com/wdvorkin/differentially_private_OPF/blob/master/Appendix.pdf)

The optimization models were implemented in [Julia](https://juliacomputing.com/products/juliapro) (v.1.4) using [JuMP](https://github.com/JuliaOpt/JuMP.jl) modeling language for mathematical optimization embedded in Julia. The models run by [Mosek](https://www.mosek.com) comercial optimization solver, which needs to be installed and licensed. 
