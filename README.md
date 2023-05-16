# ssub
## Inspiration
On SLURM-enabled HPC environments, I found that tracking job runtime status, capturing `stdout` and `stderr` outputs, and general runtime usage (CPU/RAM stats) was a bit lacking especially when compared with what LSF systems produce. I wanted a way to reproduce an LSF-like report but do so in a SLURM ecosystem, including an optional means of sending complete reports to a specified email address. This way I can search my email for past runs, either by the algorithm name or by input/output filenames used, and easily find the code and associated outputs produced. 

## Solution
The code here, written in `bash`, can be added to your `~/.bashrc` or equivalent on a SLURM-enabled HPC. It creates a function, here named `ssub`, that acts as a wrapper for `sbatch`. In effect, it submits not one but _two_ jobs: one is the actual executable as specified, the other is an `sacct` job that runs upon completion to capture all job accounting data. `ssub` then captures and combines all of this information in one log file saved locally and (if `--notify=ON`) will send the same information by email via `sendmail`. Notably, the notification system therefore will only work if your HPC compute nodes have network access, which may not be true on all systems. 

## Setup
Modify your `~/.bashrc` or equivalent and paste in the code included in `ssub.sh`. The four lines at the top need to be modified for your system as well: 

* include a path to which you would like to store your log files (`SLURMLOGLOC`), within which logs will be categorized in directories created by date and time of submission (e.g. `/path/to/SLURM_logs/2023/05/16/05_16_2023_10_11_12_134`)
* include a path to which you can store some "junk" log files, which are typically empty (`SLURMJUNKLOC`)
* include your email address at which you would like to receive the completed log files
* change the name of your default SLURM partition (`PARTITION`), here named `defq`. This will be system-dependent

## General usage
Instead of writing `bash`/`sbatch` scripts, `ssub` utilizes the one-liner syntax as in `sbatch [...] --wrap="[...]"`. So for a very simple example, let's say we want to run:
```
$ sbatch --wrap="ls -thlr"
```

SLURM typically would submit the job, and print the following to the console
```
Submitted batch job 123456
```
and a file named `slurm-123456.out` would get created with the output of the run, here a time-sorted file list of directory contents.

Using `ssub`, we instead execute with the following syntax. 

**Note: all special characters must be properly escaped, including the quotes around the `wrap` command, `<`, `>`, `|`, `$`, `%`, `&`, etc**
```
ssub --wrap=\"ls -thlr\"
```

Here, our output to the console on execution is simply the job ID (more on this below)
```
123457
```

The log file `/path/to/SLURM_logs/.../.../.../...` and the email report then contain the following example output:

```
Your job looked like:
###################################################################################
sbatch -o /path/to/SLURM_logs/2023/05/16/05_16_2023_11_16_17_776 -e /path/to/SLURM_logs//2023/05/16/05_16_2023_11_16_17_776 --time=7-12 --open-mode=append --wrap="ls -thlr"

###################################################################################

Job <123456> submitted to partition <defq>
Job email notification enabled

Current Working Directory: /home/jeremymsimon


The output (if any) follows:

total 9.5K
drwx------+ 2 jsimon jsimon   2 Apr 28 09:35 Maildir
drwxr-xr-x+ 3 jsimon jsimon   3 May  2 13:47 R
drwxrwxr-x  3 jsimon jsimon   3 May  9 13:36 SLURM_logs
drwxrwxr-x  2 jsimon jsimon  17 May 12 15:11 junk
drwxrwxr-x  6 jsimon jsimon   6 May 15 10:54 work
-rw-rw-r--+ 1 jsimon jsimon 324 May 16 11:06 slurm-4474099.out
-rw-rw-r--+ 1 jsimon jsimon 393 May 16 11:09 slurm-4474100.out


Job runtime metrics:
###################################################################################

       JobID    JobName  Partition  AllocCPUS              Submit    Elapsed      State    CPUTime     MaxRSS
------------ ---------- ---------- ---------- ------------------- ---------- ---------- ---------- ----------
123456            wrap       defq          1 2023-05-16T11:16:17   00:00:01  COMPLETED   00:00:01           
123456.bat+      batch                     1 2023-05-16T11:16:18   00:00:01  COMPLETED   00:00:01      0.00G
123456.ext+     extern                     1 2023-05-16T11:16:18   00:00:01  COMPLETED   00:00:01      0.00G

###################################################################################
```

All other parameters passed to `ssub` will also be captured and utilized in the `sbatch` command, e.g. `--mem`, `-n`, `-N`, `-d`, etc. By default, all jobs submitted with `ssub` will have `--time=7-12` but this can be reconfigured as per your HPC demands and typical usage. 

By default, the `ssub`-specific parameter `--notify` for emailed job notifications is set to `ON`, but this can be toggled off:
```
ssub --notify=OFF --wrap=\"...\"
```
The log file will still get created, but it will not be sent by email. This is useful for pipelines etc where you may not wish to get notified about every step.

## Usage with dependent jobs/pipelines
Because `ssub` simply reports the job ID upon execution, this makes executing a chain of dependent jobs (e.g. pipelines) very easy. We can write a `bash` script as follows that captures those job IDs for use with `-d afterok:jobID` so that job2 is dependent on job1 completing successfully, job3 is dependent on job2, and so on:

```
# ssub_dep_test.sh
source ~/.bashrc

# Optional: insert commands to load required modules, e.g. 
module add star/2.7.3a

jid1=$(ssub --notify=OFF --mem 20g --wrap=\" [...] \")
jid2=$(ssub --notify=OFF -d afterok:$jid1 --wrap=\" [...] \")
jid3=$(ssub --notify=OFF -d afterok:$jid2 --wrap=\" [...] \")
jid4=$(ssub -d afterok:$jid3 --wrap=\" [...] \")
```
Note we typically need to `source` our `~/.bashrc` at the top of these scripts otherwise `ssub` may not be available to the compute nodes

We execute the above with a simple `sh ssub_dep_test.sh`. If these jobs submit successfully, you won't have any text returned to the console

Here we will get four log files created with the outputs/usage stats of each, and we will get an email notification if/when the final job is successfully completed.

## Additional notes
I also like enriching my `squeue` output, so while you're modifying your `.bashrc` you could also include the following line
```
alias sjobs='squeue -u username --sort=-T,i --format="%8i     %7T     %9P   %8u    %6D     %10C   %10m   %10M   %R         %V         %Z"'
```

This creates an alias such that `sjobs` now monitors all jobs for `-u username` and formats the output of `squeue` to include the following fields:
```
JOBID        STATE       PARTITION   USER        NODES      CPUS         MIN_MEMORY   TIME         NODELIST(REASON)         SUBMIT_TIME         WORK_DIR
```

Lastly, because all emailed logs will include the subject "SLURM job <jobID>", e.g. "SLURM job 123456", this makes setting up email filters very simple. I filter these incoming messages to a separate folder/label to avoid inbox clutter by identifying all emails with "SLURM job" in the subject. 
  
You could additionally search for `FAILED` or `killed` in the email body if you'd like to label these differently or send these direct to your inbox for a higher-visibility alert.
