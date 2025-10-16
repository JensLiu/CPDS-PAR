# C compiler
# CC     =  icx
CC		= clang
OPT3 	= -g -O3
OPTG0 	= -g -O0


CFLAGS  = -g -std=c99 -Wall
CFLAGSTAR  = -g -std=c99 -Wall
OPENMP	= -fopenmp
LFLAGS  = -lm

CINCL    = -I.
CLIBS    = -L. -lm

TAREADORCC = tar-clang
TAREADOR_FLAGS = -tareador-lite

TARGETS	= heat-seq heat-tareador heat-omp
all: $(TARGETS)
.PHONY:  heat-seq heat-tareador heat-omp

heat-seq: heat-seq.c solver-seq.c misc.c
	$(CC) $(CFLAGS) $(OPT3) $+ $(LFLAGS) -o $@

heat-tareador: heat-tareador.c solver-tareador.c misc.c
	@schroot -p -c tareador make heat_tareador_env

heat_tareador_env: heat-tareador.c solver-tareador.c misc.c
	$(TAREADORCC) $(TAREADOR_FLAGS) $(CFLAGSTAR) $(OPTG0) $+ $(CINCL) -o heat-tareador $(LFLAGS) $(CLIBS)

heat-omp: heat-omp.c solver-omp.c misc.c
	$(CC) $(CFLAGS) $(OPT3) $(OPENMP) $+ $(LFLAGS) -o $@

# Debug build: compile with debug symbols and no optimizations so the
# `solver-omp.c` code can be stepped through with gdb/lldb. This keeps
# frame pointers and disables inlining/optimizations to make debugging
# easier.
DEBUGFLAGS = -g -O0 -fno-omit-frame-pointer -std=c99 -Wall

heat-omp-debug: heat-omp.c solver-omp.c misc.c
	$(CC) $(DEBUGFLAGS) $(OPENMP) $+ $(LFLAGS) -o heat-omp-debug

clean:
	rm -fr $(TARGETS) *.o .tareador_precomputed* *.log

ultraclean:
	rm -fr $(TARGETS) logs *.sh.o* *.sh.e* *.o *.ppm .tareador_precomputed* *.prv *.pcf *.row dependency_graph* *.times.txt *.ps *.txt *.log TRACE.* set-0 logs

gen-heat-omp: heat-omp
	./heat-omp test.dat -a 0 -o heat-jacobi-omp.ppm && \
	./heat-omp test.dat -a 1 -o heat-gauss-omp.ppm

original-ppms: heat-seq
	./heat-seq test.dat -a 0 -o heat-jacobi-seq.ppm && \
	./heat-seq test.dat -a 1 -o heat-gauss-seq.ppm
	
cfg-gcc: heat-omp.c solver-omp.c misc.c
	cd cfgs && \
	rm -fr * && \
	gcc $(CFLAGS) $(OPT3) $(OPENMP) ../heat-omp.c ../solver-omp.c ../misc.c $(LFLAGS) -fdump-tree-optimized-graph && \
	dot -Tpdf a-heat-omp.c.254t.optimized.dot -o heat-cfg.pdf && \
	dot -Tpdf a-solver-omp.c.254t.optimized.dot -o solver-cfg.pdf

cfg-clang: heat-omp.c solver-omp.c misc.c
	rm -rf cfgs/* && \
	cd cfgs && \
	clang -S -emit-llvm $(OPENMP) $(CFLAGS) $(OPT3) ../heat-omp.c ../solver-omp.c ../misc.c $(LFLAGS) && \
	opt -passes=dot-cfg -disable-output solver-omp.ll && \
	opt -passes=dot-cfg -disable-output heat-omp.ll && \
	opt -passes=dot-cfg -disable-output misc.ll && \
	dot -Tpdf .solve_gauss.dot -o solve_gauss.pdf && \
	dot -Tpdf .solve_gauss.omp_outlined.dot -o solve_gauss_outlined.pdf && \
	dot -Tpdf ..omp_task_entry..dot -o omp_task_entry.pdf && \
	dot -Tpdf .main.dot -o main.pdf \



