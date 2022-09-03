# DP-CC-OPF: Differentially Private Chance-Constrained OPF

This repository contains supplementary materials for the paper __Differentially Private Optimal Power Flow for Distribution Grids__ by V. Dvorkin, F. Fioretto, P. Van Hentenryck, J. Kazempour, and P. Pinson.

The proof of Theorem 2 is contained in [Appendix.pdf](https://github.com/wdvorkin/differentially_private_OPF/blob/master/Appendix.pdf)

The optimization models were implemented in [Julia](https://juliacomputing.com/products/juliapro) (v.1.4) using [JuMP](https://github.com/JuliaOpt/JuMP.jl) modeling language for mathematical optimization embedded in Julia. The models require [Mosek](https://www.mosek.com) comercial optimization solver, which needs to be installed and licensed. 

To activate the packages in ```Project.toml```, clone the project, e.g., using ```git clone```, and ```cd``` to the project directory and call
```
$ julia 
julia> ]
(@v1.4) pkg> activate .
(DP_CC_OPF) pkg> instantiate
```
where ```julia``` is an alias to Julia installation. To run the code, ```cd``` to the project directory and call
```
$ julia DP_CC_OPF.jl
```

By default, the program returns the solution of the ```"CC_OPF"``` mechanism and stores the results in ```~/output/CC_OPF```. To run the other mechanisms, parse ```"D_OPF"```, ```"ToV_CC_OPF"```, ```"TaV_CC_OPF"``` or ```"CVaR_CC_OPF"``` using option ```-m```, e.g. 
```
$ julia DP_CC_OPF.jl -m "CVaR_CC_OPF"
```
The results will be stored in ```~/output/CVaR_CC_OPF```. 
