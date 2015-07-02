using Augur

tests = [
    "setup",
    # "test_makedata",
    "test_consensus",
    "test_metrics",
    "test_simulate",
    "test_repl",
    # "test_plots",
    # "test_statistics",
]

print_with_color(:blue, "Testing Simulator.jl...\n")

for t in tests
    tfile = string(t, ".jl")
    print_with_color(:white, " * $(tfile)\n")
    include(tfile)
end
