#!/bin/bash

#SBATCH --job-name=submit-userparam-omp.sh
#SBATCH -D .
#SBATCH --output=submit-userparam-omp.sh.o%j
#SBATCH --error=submit-userparam-omp.sh.e%j

USAGE="\n USAGE: ./submit-userparam-omp.sh numthreads \n
    numthreads  -> Number of threads in parallel execution \n"

if (test $# -lt 1 || test $# -gt 1)
then
    echo -e $USAGE
    exit 0
fi

HOST=$(echo $HOSTNAME | cut -f 1 -d'.')

if [ ${HOST} = 'boada-11' ] || [ ${HOST} = 'boada-12' ] || [ ${HOST} == 'boada-13' ]
then
    echo "Use sbatch to execute this script"
    exit 0
fi

SEQ=heat-seq
PROG=heat-omp

# Make sure that all binaries exist
make $SEQ
make $PROG

export KMP_AFFINITY=scatter
export OMP_NUM_THREADS=$1
export OMP_WAIT_POLICY="passive"

values="1 2 4 8 16 32 64 128 256 512 1024"

i=1
out=$PROG-$OMP_NUM_THREADS-userparam.txt

rm -rf $out
rm -rf ./elapsed.txt
for value in $values
do
    echo $value >> $out
    ./$PROG test.dat -a 1 -n 1000 -s 1022 -u $value >> $out
    result=`cat $out | tail -n 3  | grep "Time"| cut -d':' -f 2`
    echo $i >> ./elapsed.txt
    echo $result >> ./elapsed.txt
    i=`echo $i + 1 | bc -l`
done

i=1
rm -rf ./hash_labels.txt
for value in $values
do
    echo "hash_label at " $i " : " $value >> ./hash_labels.txt
    i=`echo $i + 1 | bc -l`
done

jgraph -P userparam-omp.jgr > $PROG-$OMP_NUM_THREADS-userparam.ps
usuario=`whoami`
fecha=`date`
sed -i -e "s/UUU/$usuario/g" $PROG-$OMP_NUM_THREADS-userparam.ps
sed -i -e "s/FFF/$fecha/g" $PROG-$OMP_NUM_THREADS-userparam.ps
rm -rf ./hash_labels.txt
