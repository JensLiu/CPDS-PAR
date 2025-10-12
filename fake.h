volatile int __kk=0; // volatile to avoid optimizations

void trace_mark()
{
 // fake parallel region to delimit the start/end of user code in trace
 #pragma omp parallel num_threads(1)
 #pragma omp atomic
   __kk++; // trying to avoid optimizations
}


#define TRACE_START_MARK  trace_mark();

#define TRACE_END_MARK    trace_mark();
