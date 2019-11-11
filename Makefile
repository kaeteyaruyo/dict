TESTS = test_cpy test_ref

TEST_DATA = s Tai

CFLAGS = -O0 -Wall -Werror -g

# Control the build verbosity
ifeq ("$(VERBOSE)","1")
    Q :=
    VECHO = @true
else
    Q := @
    VECHO = @printf
endif

GIT_HOOKS := .git/hooks/applied

.PHONY: all clean

all: $(GIT_HOOKS) $(TESTS)

$(GIT_HOOKS):
	@scripts/install-git-hooks
	@echo

OBJS_LIB = \
    tst.o bloom.o

OBJS := \
    $(OBJS_LIB) \
    test_common.o

deps := $(OBJS:%.o=.%.o.d)

test_ref: FORCE
	$(MAKE) test_exe MODE=REF

test_cpy: FORCE
	$(MAKE) test_exe MODE=CPY

test_exe: test_common.o $(OBJS_LIB)
	$(VECHO) "  LD\t$@\n"
	$(Q)$(CC) $(LDFLAGS)  -o test_$(shell echo $(MODE) | tr A-Z a-z) $^ -lm

%.o: %.c
	$(VECHO) "  CC\t$@\n"
	$(Q)$(CC) -D$(MODE) -o $@ $(CFLAGS) -c -MMD -MF .$@.d $<

test:  $(TESTS)
	echo 3 | sudo tee /proc/sys/vm/drop_caches;
	perf stat --repeat 100 \
                -e cache-misses,cache-references,instructions,cycles \
                ./test_cpy --bench $(TEST_DATA)
	perf stat --repeat 100 \
                -e cache-misses,cache-references,instructions,cycles \
				./test_ref --bench $(TEST_DATA)

bench: $(TESTS)
	@for test in $(TESTS); do \
	    echo -n "$$test => "; \
	    ./$$test --bench $(TEST_DATA); \
	done

plot: $(TESTS)
	echo 3 | sudo tee /proc/sys/vm/drop_caches;
	perf stat --repeat 100 \
                -e cache-misses,cache-references,instructions,cycles \
                ./test_cpy --bench $(TEST_DATA) \
		| grep 'ternary_tree, loaded 259112 words'\
		| grep -Eo '[0-9]+\.[0-9]+' > cpy_data.csv
	perf stat --repeat 100 \
                -e cache-misses,cache-references,instructions,cycles \
				./test_ref --bench $(TEST_DATA)\
		| grep 'ternary_tree, loaded 259112 words'\
		| grep -Eo '[0-9]+\.[0-9]+' > ref_data.csv

clean:
	$(RM) $(TESTS) $(OBJS)
	$(RM) $(deps)
	$(RM) bench_cpy.txt bench_ref.txt ref.txt cpy.txt
	$(RM) *.csv

FORCE: ;

-include $(deps)