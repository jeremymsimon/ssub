export SLURMLOGLOC=/path/to/SLURM_logs/
export SLURMJUNKLOC=/path/to/junk/
export EMAIL='name@email.com'
export PARTITION='defq'

function ssub {
        day=$(date '+%Y/%m/%d')
        mkdir -p $SLURMLOGLOC/$day
        log=$(date '+%m_%d_%Y_%H_%M_%S_%3N')
        cmd="sbatch -o $SLURMLOGLOC/$day/$log -e $SLURMLOGLOC/$day/$log --time=7-12 --open-mode=append $*"
        mkdir -p $SLURMJUNKLOC/
        notify=$(echo $cmd | sed -nE 's/.+notify.(\w+).+/\1/p')
        if ! { [ "$notify" = "ON" ] || [ "$notify" = "OFF" ]; }; then
                notify="ON"
        fi

		cmd2=$(echo $cmd | sed -E 's/--notify\=\w+ //')

        echo -e "Your job looked like:\n###################################################################################" >> $SLURMLOGLOC/$day/$log
        echo $cmd2 >> $SLURMLOGLOC/$day/$log
        echo -e "\n###################################################################################\n" >> $SLURMLOGLOC/$day/$log
        jobID="$(eval $cmd2 | cut -f 4 -d ' ')"

        if [ "$notify" = "ON" ]; then
                memory="sbatch -o $SLURMJUNKLOC/$log -d afterany:$jobID --partition $PARTITION --wrap=\"echo -e '\n\nJob runtime metrics:\n###################################################################################\n' >> $SLURMLOGLOC/$day/$log;\
                sacct --format="JobID,JobName,Partition,AllocCPUS,Submit,Elapsed,State,CPUTime,MaxRSS" --units=G -j $jobID >> $SLURMLOGLOC/$day/$log;\
		echo -e '\n###################################################################################\n' >> $SLURMLOGLOC/$day/$log;\
                echo 'Subject: SLURM job $jobID' | cat - $SLURMLOGLOC/$day/$log | sendmail $EMAIL\""
        elif [ "$notify" = "OFF" ]; then
                memory="sbatch -o $SLURMJUNKLOC/$log -d afterany:$jobID --partition $PARTITION --wrap=\"echo -e '\n\nJob runtime metrics:\n###################################################################################\n' >> $SLURMLOGLOC/$day/$log;\
                sacct --format="JobID,JobName,Partition,AllocCPUS,Submit,Elapsed,State,CPUTime,MaxRSS" --units=G -j $jobID >> $SLURMLOGLOC/$day/$log;\
                echo -e '\n###################################################################################\n' >> $SLURMLOGLOC/$day/$log\""
        fi
		memoryID="$(eval $memory | cut -f 4 -d ' ')"

        queue=$(echo $cmd2 | sed -nE 's/.+partition.(\w+).+/\1/p')
        if [ "$partition" = "" ]; then
                queue=$PARTITION
        fi

		echo "Job <$jobID> submitted to partition <$queue>" >> $SLURMLOGLOC/$day/$log

        if [ $notify = "ON" ]; then
                echo -e "Job email notification enabled\n" >> $SLURMLOGLOC/$day/$log
        elif [ $notify = "OFF" ]; then
                echo -e "Job email notification disabled\n" >> $SLURMLOGLOC/$day/$log
        fi

		echo "$jobID"
        wd=$(pwd)
        echo -e "Current Working Directory: $wd\n\n" >> $SLURMLOGLOC/$day/$log
        echo -e "The output (if any) follows:\n" >> $SLURMLOGLOC/$day/$log
}
