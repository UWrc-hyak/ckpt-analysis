#ckpt data analysis
#purpose: 
#1. find a mean job run time
#2. does requested job time correlate with job time
#finchnsnps

#set working directory----
#setwd("/Users/kristenfinch/Documents/sacct_data")

#install packages----
install.packages("tidyverse")

#libraries----
library(tidyverse)

#color palette----
#color blindness accessible
cbPalette <- c("#999999", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")

#data----
ckpt<-read.csv("sacct_ckpt_data.csv",header=1, quote = "",row.names = NULL,stringsAsFactors = FALSE)

ckpt$X<-NULL

#ckpt only
ckpt<-ckpt%>%filter(Partition == "ckpt")

ckpt$TimelimitRaw<-as.numeric(ckpt$TimelimitRaw)
ckpt$ElapsedRaw<-as.numeric(ckpt$ElapsedRaw)
summary(ckpt$ElapsedRaw)

#column added to convert time from seconds to minutes
ckpt<-ckpt%>%mutate(ElapsedRawMin = ElapsedRaw/60)

#average job time = 42 min
summary(ckpt$ElapsedRawMin)

#summary of time limit requests
summary(ckpt$TimelimitRaw)

ckpt$ReqMem<-gsub("G","",ckpt$ReqMem)
ckpt$ReqMem<-as.numeric(ckpt$ReqMem)

#separating JobID into JobID and slurm index for array jobs. this is to make a
#new column indicating if a job is an array job.
ckpt<-ckpt%>%separate(State,into=c("State","byNote"),sep=" by ",remove=FALSE)%>%separate(JobID,into=c("Job","JobArray_index"),sep="_",remove=FALSE)

ckpt$array_job <- ifelse(is.na(ckpt$JobArray_index),"no", "yes")
head(ckpt)
table(ckpt$array_job)

table(ckpt$State)

#some unlimited jobs identified and saved elsewhere
unlimited_jobs<-ckpt%>%filter(ElapsedRawMin>=307)
#write.csv(unlimited_jobs,"unlimited_jobs.csv",row.names=FALSE,quote=FALSE)

#filter to remove the unusual unlimited jobs
ckpt<-ckpt%>%filter(!JobID %in% unlimited_jobs$JobID)

#all jobs plots----

#filtering to remove job states "PENDING" and "RUNNING" at time of data
#acquisition to simplify visualizations.

#bar chart to show jobs per state, fill proportions show proportion of the job
#that were submitted as array jobs.
(state_bar<-ggplot(aes(x=State,fill=array_job,color=Partition),
                   data=ckpt%>%filter(State != "PENDING")%>%filter(State != "RUNNING"))+
  geom_bar(size=.5)+
  scale_color_manual(values = c("black"),guide=FALSE)+
  scale_fill_manual(values = c("white","darkgray"),name="Array Job?",labels=c("","yes"))+ 
  labs(x="State",y="Number of Jobs",title="Jobs by State")+
  #ylim(c(0,6050))+
  theme_bw()+
  theme(legend.position = "bottom",
        legend.text = element_text(size=6),
        legend.title = element_text(size=7),
        axis.text.x=element_text(size=6.25),
        axis.title.x=element_text(size=8),
        axis.text.y=element_text(size=6.5),
        axis.title.y=element_text(size=8)))

ggsave("jobsxstate_bar.jpg",state_bar,width=6,height=4)

#histogram to show distribution of run times, colored by proportion of jobs in each job state
(job_time_dist<-ggplot()+geom_histogram(data = ckpt%>%filter(State != "PENDING")%>%filter(State != "RUNNING"),
                        aes(x=ElapsedRawMin,fill=State))+
  scale_fill_manual(values=cbPalette)+
  geom_vline(xintercept=305,size=1,color="firebrick")+
  labs(x="Job time (min)",y="Count",title="Jobs since January 1, 2024 (n=1,154,972)")+
  theme_bw()+
    theme(legend.text = element_text(size=6),
          legend.title = element_text(size=7),
          axis.text.x=element_text(size=6.25),
          axis.title.x=element_text(size=8),
          axis.text.y=element_text(size=6.5),
          axis.title.y=element_text(size=8)))

ggsave("jobsxtime_dist.jpg",job_time_dist,width=6,height=4)

#plots for job times summed by JobID----

#job run times were summed across JobID to combine the same job after requeue, preemption, etc.
#filtered to remove jobs job states "PENDING" and "RUNNING" at time of data
#acquisition to simplify visualizations.

byJobID<-ckpt%>%filter(State != c("RUNNING","PENDING"))

byJobID<-ckpt[c(1,20,15)]%>%group_by(JobID)%>%summarise_all(funs(sum))
names(byJobID)<-c("JobID","SumElapsedRawMin","SumTimelimitRaw")
dim(byJobID)

#columns for time in hours
byJobID<-byJobID%>%mutate(SumElapsedRawHr=SumElapsedRawMin/60)
byJobID<-byJobID%>%mutate(SumTimelimitRawHr=SumTimelimitRaw/60)

#column to indicate if the job is longer than 5.08 (or 5:05)
byJobID$above_lim<-ifelse(byJobID$SumElapsedRawHr>=5.08,"yes", "no")

#linear model explorations----

#there is a weak but significant linear relationship between job runtime and requested time limit
coefficient <- cor.test(byJobID$SumElapsedRawHr, byJobID$SumTimelimitRawHr)
coefficient$estimate #weakly linear

(model<-lm(SumElapsedRawHr~SumTimelimitRawHr,data=byJobID))
summary(model) #weak but significant relationship

res <- resid(model)
#produce residual vs. fitted plot
plot(fitted(model), res)
#add a horizontal line at 0 
abline(0,0)

#create Q-Q plot for residuals
qqnorm(res)
#add a straight diagonal line to the plot
qqline(res) #non-normal

#scatterplot to show relationship between job time requested and job time color
#coding of the points makes it look like most of the jobs are above the time
#limit because the plotting shows many many points overlapping.
(elapsedxrequest<-ggplot()+geom_point(data = byJobID,aes(y=SumElapsedRawHr,x=SumTimelimitRawHr,color=above_lim))+
  #geom_hline(yintercept=5.08,size=1,color="firebrick")+
  scale_color_manual(values=c("#E69F00","#999999"),labels=c("≥ 5:05","< 5:05"),name="Elapsed time")+
  labs(x="Time limit requested (hr)",y="Elapsed time (hr)",title="Times summed across JobID (n=940,442)")+
  theme_bw()+
  theme(legend.text = element_text(size=6),
        legend.title = element_text(size=7),
        axis.text.x=element_text(size=6.25),
        axis.title.x=element_text(size=8),
        axis.text.y=element_text(size=6.5),
        axis.title.y=element_text(size=8)))

ggsave("elapsedxrequest_scat.jpg",elapsedxrequest,width=6,height=4)

#most jobs are below the time limit even when summed by JobID
table(byJobID$above_lim)
new_labs<-c("≥ 5:05 (n=922,317)","< 5:05 (n=18,125)")
names(new_labs)<-c("no","yes")

#facetted plot to show the distribution of job times for jobs below the ckpt time
#limit (5 hours and 5 minutes) and jobs above the time limit.
(job_times<-ggplot()+geom_histogram(data = byJobID,aes(x=SumElapsedRawHr),bins=50)+
  facet_wrap(~above_lim,scales="free",labeller=labeller(above_lim = new_labs))+
  #geom_vline(xintercept=5,size=1,color="firebrick")+
  labs(x="Elapsed time (hr)",y="Count",title="Jobs since January 1, 2024 (n=940,442)")+
  theme_bw()+
  theme(legend.text = element_text(size=6),
        legend.title = element_text(size=7),
        axis.text.x=element_text(size=6.25),
        axis.title.x=element_text(size=8),
        axis.text.y=element_text(size=6.5),
        axis.title.y=element_text(size=8)))

ggsave("jobtimes_facet.jpg",job_times,width=6,height=4)

#summary of job times summer across JobID
summary(byJobID$SumElapsedRawHr)

#just requeued/preempted/completed---- 

#I want to look at jobs that were completed, requeued, or preempted to see how
#many jobs would be affected by increasing the ckpt time limit to 10 hours.
byJobID_rpc<-ckpt%>%filter(State != c("RUNNING","PENDING"))%>%filter(State != c("NODE_FAIL","FAILED"))%>%filter(State != c("OUT_OF_MEMORY","TIMEOUT"))%>%filter(State != "CANCELLED")

byJobID_rpc<-byJobID_rpc[c(1,20,15)]%>%group_by(JobID)%>%summarise_all(funs(sum))
names(byJobID_rpc)<-c("JobID","SumElapsedRawMin","SumTimelimitRaw")
dim(byJobID_rpc)

#columns for time in hours
byJobID_rpc<-byJobID_rpc%>%mutate(SumElapsedRawHr=SumElapsedRawMin/60)
byJobID_rpc<-byJobID_rpc%>%mutate(SumTimelimitRawHr=SumTimelimitRaw/60)

#column to indicate if the job is longer than 5.08 (or 5:05)
byJobID_rpc$above_lim<-ifelse(byJobID_rpc$SumElapsedRawHr>=5.08,"yes", "no")

#column to indicate if the job is longer than 10 hr
byJobID_rpc$above_10<-ifelse(byJobID_rpc$SumElapsedRawHr>=10,"yes", "no")

#about 10,000 additional jobs would be able to complete with increase
nrow(byJobID_rpc%>%filter(above_10=="no"))-nrow(byJobID_rpc%>%filter(above_lim=="no"))

#extra plots----

#histogram to show proportion of jobs that were array jobs
ggplot()+geom_histogram(data = ckpt,aes(x=ElapsedRawMin,fill=array_job))+
  scale_fill_manual(values=cbPalette)+
  geom_vline(xintercept=305,size=1,color="firebrick")+
  labs(x="Job time (min)",y="Count",title="Jobs since January 1, 2024 (n=1,156,650)")+
  theme_bw()

#boxplot showing run times vs. job state
ggplot()+geom_boxplot(data = ckpt%>%filter(State != "PENDING")%>%filter(State != "RUNNING"),
                      aes(y=ElapsedRawMin,x=State),outlier.shape = NA)+
  geom_hline(yintercept=305,size=1,color="firebrick")+
  labs(x="State",y="Job Time (min)",title="Jobs since January 1, 2024 (n=1,154,972)")+
  theme_bw()+
  theme(legend.text = element_text(size=6),
        legend.title = element_text(size=7),
        axis.text.x=element_text(size=6.25),
        axis.title.x=element_text(size=8),
        axis.text.y=element_text(size=6.5),
        axis.title.y=element_text(size=8))