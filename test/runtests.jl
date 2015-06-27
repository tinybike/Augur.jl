using Simulator

tests = [
    "setup",
    # "test_makedata",
    "test_simulate",
    "test_repl",
    "test_metrics",
    # "test_plots",
]

print_with_color(:blue, "Testing Simulator.jl...\n")

for t in tests
    tfile = string(t, ".jl")
    print_with_color(:white, " * $(tfile) ...\n")
    include(tfile)
end
