using Augur

tests = [
    "setup",
    "test_makedata",
    "test_consensus",
    "test_metrics",
    "test_simulate",
    "test_repl",
]

print_with_color(:blue, "Testing Augur.jl...\n")

for t in tests
    tfile = string(t, ".jl")
    print_with_color(:white, " * $(tfile)\n")
    include(tfile)
end
