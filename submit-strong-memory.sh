#!/bin/bash

#SBATCH --job-name=submit-strong-memory.sh
#SBATCH -D .
#SBATCH --output=submit-strong-memory.sh.o%j
#SBATCH --error=submit-strong-memory.sh.e%j

USAGE="\n USAGE: ./submit-strong-memory.sh prog \n
        prog        -> Program name\n
        solver      -> 0: Jacobi; 1: Gauss-Seidel\n"

if (test $# -lt 2 || test $# -gt 2)
then
        echo -e $USAGE
        exit 0
fi

make $1

HOST=$(echo $HOSTNAME | cut -f 1 -d'.')

if [ ${HOST} = 'boada-11' ] || [ ${HOST} = 'boada-12' ] || [ ${HOST} == 'boada-13' ]
then
    echo "Use sbatch to execute this script"
    exit 0
fi

export np_MIN=1
export np_MAX=16
export np_STEP=2
export EXTRAE_CONFIG_FILE=extrae.xml

#Preparing the directory that will receive all pre-processed traces
OUTDIR=$1-strong-memory
rm -rf $OUTDIR
mkdir $OUTDIR

P=$np_MIN
userparam=16
outputpathl2=./l2_misses-$1-${HOST}.txt
rm -rf $outputpathl2
while (test $P -le $np_MAX)
do
    echo Tracing $1 with $P threads

    #Tracing the application with P threads
    export OMP_NUM_THREADS=$P
    export LD_PRELOAD=${INTEL_PATCH}/libhack.so:${EXTRAE_HOME}/lib/libomptrace.so
    ./$1 test.dat -a $2 -n 1000 -s 1022 -u $userparam
    export LD_PRELOAD=${INTEL_PATCH}/libhack.so

    #Generating the trace
    mpi2prv -f TRACE.mpits -o $OUTDIR/$1-$P-${HOST}.prv -e $1 -paraver
    rm -rf  TRACE.mpits set-0 >& /dev/null

    #Finding the trace limits as delimited by the initial and final "fake" parallel region
    start=$(grep 60000001 $OUTDIR/$1-$P-${HOST}.prv | head -n2 | tail -n1 | cut -d ":" -f 6)
    start=$((start+1))
    end=$(grep 60000001 $OUTDIR/$1-$P-${HOST}.prv | tail -n2 | head -n1 | cut -d ":" -f 6)
    end=$((end-1))

    #Generating the xml file for cutting the original trace
    cp $BASICANALYSIS_HOME/.cutter.xml $OUTDIR/cutter-$P.xml
    sed -i -e "s/LLL/$start/g" $OUTDIR/cutter-$P.xml
    sed -i -e "s/UUU/$end/g" $OUTDIR/cutter-$P.xml

    #Cutting the trace for proper analysis
    paramedir $OUTDIR/$1-$P-${HOST}.prv -c $OUTDIR/cutter-$P.xml -o $OUTDIR/$1-$P-${HOST}-cutter.prv
    rm $OUTDIR/$1-$P-${HOST}.*
    rm $OUTDIR/cutter-$P.xml
    l2d_misses=$(grep 42000007 $OUTDIR/$1-$P-${HOST}-cutter.prv | awk -F "42000007:" '{print $2}' | awk -F: '{sum+=$1} END{print sum;}')
    l2d_misses_normalized=`expr $l2d_misses / $P`
    echo $P $l2d_misses $l2d_misses_normalized >> $outputpathl2

    i
    #Find the next number of threads
    if (test $P -eq 1) then
        P=4;
    else
        P=`expr $P \* $np_STEP`
    fi
done
export EXTRAE_CONFIG_FILE="/Soft/PAR/extrae.xml"

cd $OUTDIR
rm -rf scratch_out_basicanalysis
