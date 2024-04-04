# ckpt Partition Job Time Analysis


The purpose of this analysis was: 
1. to find a mean job run time `ckpt`.
2. to understand if requsted job time (`sbatch` directive `--time=`) correlates with job run time (`sacct --format ElapsedRaw`). 

### Data Acquisition

Data for this analysis was derived from SLURM with the command `sacct` for `ckpt` using the following command, which requests all jobs since January 1, 2024 keeping duplicates and array jobs separate with the listed format columns. `--parsable` prepared a "|" delimited file. 

```bash
$ sacct -a -r ckpt -S 2024-01-01T00:00:00 --array --parsable --duplicates --format User,JobID,JobName,Partition,Account,AllocCPUS,State,Elapsed,ElapsedRaw,CPUTime,CPUTimeRAW,Timelimit,TimelimitRaw,ReqMem,NodeList,Reason,End>sacct_ckpt_data.parsable
```
Convert this file to comma delimited format. 

```bash
$ sed 's/|/,/g' sacct_ckpt_data.parsable>sacct_ckpt_data.csv
```
### Data Analysis

Post processing and data visualization was performed in R.
[ckpt_analysis.R](https://github.com/UWrc-hyak/ckpt-analysis/blob/main/ckpt_analysis.R)

### Summaries and Selected Plots

Data was acquired on Mar 29 19:44 and included 1,156,650 jobs. This number includes separate instanced of the same JobID that was requeued or pre-empted. Of these jobs, 493,965 were array jobs (42.7%). 

![](/selected_plots/jobsxstate_bar.jpg 'Jobs by State')
The bar chart to shows jobs per state, gray proportions show proportion of the job that were submitted as array jobs (does not include PENDING and RUNNING Jobs).


| Job State        |      Number of Jobs      |
| ------------- | :-----------: |
| CANCELLED      | 311421 |
| COMPLETED      |   437557    |
| FAILED |   148602    |
| NODE_FAIL |   232    |
| OUT_OF_MEMORY |   10793    |
| PENDING |   1432    |
| PREEMPTED |   108577    |
| REQUEUED |   110962    |
| RUNNING |   264    |
| TIMEOUT |   26828    |


Average job run time was 42.4 min (range 0-305.8 min), which makes sense given the time limit (~305 min).

![](/selected_plots/jobsxtime_dist.jpg 'Job Time Dist')
The histogram shows distribution of run times, colored by proportion of jobs in each job state (does not include PENDING and RUNNING Jobs). The vertical red line indicates the `ckpt` time limit (305 min). 

Job run times were summed across JobID to combine the same job after requeue, preemption, etc. filtered to remove jobs job states "PENDING" and "RUNNING" at time of data acquisition to simplify visualizations. This led to 940,442 jobs. 

![](/selected_plots/elapsedxrequest_scat.jpg 'Scatterplot')
The scatterplot shows relationship between job time requested (`sbatch --time=`) and job time (`sacct --format ElapsedRaw`). Points were color coded if the summed run time was less than the time limit (gold). The color coding makes it look like most run times were above the time limit because the plotting shows many many points overlapping.

However, this was not the case. The majority of jobs had summed run times under the time limit (922,317; 98.1%). 

![](/selected_plots/jobtimes_facet.jpg 'Dist Facet')
The facetted histograms shows the distribution of job times for jobs below the `ckpt` time limit (5 hours and 5 minutes) and jobs above the time limit. Notice the sample sizes and the distinct scales. 

On average summed job run time for `ckpt` since January 1, 2024 was 0.87 hours (or 52.1 min; range 0-834.6 hrs). 

### Observations

* It seems like most folks have adapted to the `ckpt` time limit and use it for short jobs except in rare cases. 98% of summed job time is less than the current limit (305 min).
* Although unlikely, if the current mean run time remains consistent (42 - 52 min), increasing `ckpt` time limit by a few hours would not change dramatically change the run time distribution on `ckpt`. 

> For example,  when considering only COMPLETED, REQUEUED, and PREEMPTED job states, (n=576,873 jobs), the majority of jobs are under the current limit (560,514 jobs;97%) and if the time limit were increased to 10 hours 568,996 jobs would be under the limit (99%) or a difference of 8,482 jobs. Preempted would still be preempted. 

* However, a minor increse might mean that a small percentage of jobs (maybe 2%) do not have to be requeued, saving some SLURM traffic.  
* Increasing `ckpt` time limit would probably lead to more `ckpt` traffic in general since folks will adpat to the new time limit and start sending jobs that migh tbe expected to take longer, and could expand `ckpt` usage by demo accounts.
* There was a weak but significant postitive linear relationship between job run time and requsted job time (`sbatch` directive `--time=`) (R-squared = 0.129). However, the data violates the assumption normality. Folks are requesting adequate time for their jobs, but there are some cases of requesting very long time limits I suppose to gaurenteed the job will finish. 




