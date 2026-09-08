# Run from the abm_extension directory with Rscript --vanilla R/analyze_extension.R.
# Optional --sensitivity requires all prespecified sensitivity cells to exist.
options(warn = 2)
stopifnot(dir.exists('output'), file.exists('data/processed/experimental_group_session.csv'))
library(ggplot2)
dir.create('output/figures', showWarnings = FALSE)
metrics <- c('group_relative_contribution', 'surplus', 'gini', 'success')
treatments <- c('FE', 'AI', 'MI')
games <- c('linear', 'threshold')
experimental <- read.csv('data/processed/experimental_group_session.csv')
experimental_round <- read.csv('data/processed/experimental_group_round.csv')
stopifnot(nrow(experimental) == 294, ncol(experimental) == 8)
stopifnot(nrow(experimental_round) == 5880, ncol(experimental_round) == 9)
stopifnot(!anyDuplicated(experimental[c('game','Treatment','Session','GroupID')]))

read_suite <- function(name) {
  parts <- list()
  for (game in games) for (treatment in treatments) {
    file <- file.path('output', name, paste0(game, '_', treatment), 'chain_summary.csv')
    stopifnot(file.exists(file))
    d <- read.csv(file)
    stopifnot(!anyDuplicated(d$run_id), !anyNA(d[setdiff(names(d), c('success','snapshot_success'))]))
    stopifnot(all(d$game == game), all(d$treatment == treatment), all(d$experiment == name))
    stopifnot(all(d$post_burn_profiles == d$steps - d$burn_in))
    parts[[length(parts)+1]] <- d
  }
  do.call(rbind, parts)
}

summarize_chains <- function(d) {
  rows <- list()
  for (game in games) for (treatment in treatments) for (metric in metrics) {
    if (game == 'linear' && metric == 'success') next
    part <- d[d$game == game & d$treatment == treatment, ]
    x <- part[[metric]]
    stopifnot(length(x) >= 2, !anyNA(x), !anyDuplicated(part$seed))
    se <- sd(x)/sqrt(length(x))
    radius <- qt(.975, df=length(x)-1)*se
    rows[[length(rows)+1]] <- data.frame(
      experiment=unique(part$experiment), game=game, treatment=treatment, metric=metric,
      simulation_mean=mean(x), mc_se=se, mc_lower=mean(x)-radius, mc_upper=mean(x)+radius,
      n_seeds=length(x), seed_sd=sd(x), seed_p10=unname(quantile(x,.1)), seed_p90=unname(quantile(x,.9)),
      snapshot_mean=mean(part[[paste0('snapshot_',metric)]]))
  }
  do.call(rbind, rows)
}

baseline <- read_suite('baseline')
stopifnot(nrow(baseline) == 192)
summary <- summarize_chains(baseline)
summary$experimental_mean <- NA_real_
summary$experimental_session1_mean <- NA_real_
summary$experimental_session2_mean <- NA_real_
summary$experimental_n_group_sessions <- NA_integer_
for (i in seq_len(nrow(summary))) {
  row <- summary[i, ]
  d <- experimental[experimental$game == row$game & experimental$Treatment == row$treatment, ]
  summary$experimental_mean[i] <- mean(d[[row$metric]])
  summary$experimental_session1_mean[i] <- mean(d[[row$metric]][d$Session == 1])
  summary$experimental_session2_mean[i] <- mean(d[[row$metric]][d$Session == 2])
  summary$experimental_n_group_sessions[i] <- nrow(d)
}
summary$simulation_minus_experiment <- summary$simulation_mean - summary$experimental_mean
summary$snapshot_minus_all_steps <- summary$snapshot_mean - summary$simulation_mean
summary$experimental_uncertainty <- 'Descriptive pooled means; no iid pooled CI because participants recur across sessions'
summary$simulation_uncertainty <- '95% t interval across independent finite-chain means; not model uncertainty or convergence proof'
write.csv(summary, 'output/comparison.csv', row.names=FALSE, na='')
write.csv(baseline, 'output/baseline_chain_summary.csv', row.names=FALSE, na='')

# Four main panels, with experimental points and MC intervals explicitly distinguished.
plot_data <- summary[(summary$game == 'linear' & summary$metric %in% c('group_relative_contribution','surplus')) |
                       (summary$game == 'threshold' & summary$metric %in% c('success','surplus')), ]
panel_names <- c('linear_group_relative_contribution'='Linear: relative contribution',
                 'linear_surplus'='Linear: surplus / endowment',
                 'threshold_success'='Threshold: success rate',
                 'threshold_surplus'='Threshold: surplus / endowment')
plot_data$panel <- factor(panel_names[paste(plot_data$game,plot_data$metric,sep='_')],levels=unname(panel_names))
plot_data$treatment <- factor(plot_data$treatment, levels=treatments)
comparison_plot <- ggplot(plot_data, aes(x=treatment)) +
  geom_point(aes(y=experimental_mean, color='Experiment: pooled mean',shape='Experiment: pooled mean'),
             position=position_nudge(x=-.10),size=3) +
  geom_errorbar(aes(ymin=mc_lower,ymax=mc_upper,color='Simulation: mean + 95% MC CI'),
                position=position_nudge(x=.10),width=.07,linewidth=.6) +
  geom_point(aes(y=simulation_mean,color='Simulation: mean + 95% MC CI',shape='Simulation: mean + 95% MC CI'),
             position=position_nudge(x=.10),size=3) +
  facet_wrap(~panel,scales='free_y',ncol=2) +
  scale_color_manual(values=c('Experiment: pooled mean'='#176B70','Simulation: mean + 95% MC CI'='#B24D32')) +
  scale_shape_manual(values=c('Experiment: pooled mean'=16,'Simulation: mean + 95% MC CI'=18)) +
  labs(title='Four-player ABM: an uncalibrated transfer check',
       subtitle='Published dyadic learning parameters; 32 seeds per treatment; finite 6,000-revision runs',
       x=NULL,y='Outcome (fraction)',color=NULL,shape=NULL,
       caption=paste('FE = full equality; AI = aligned inequality; MI = misaligned inequality.',
                     'Experimental means use 20-round group-session averages. MC intervals describe simulation randomness only.',
                     'No four-player fitting; no claim of stationary convergence.',sep='\n')) +
  theme_minimal(base_size=12) + theme(legend.position='bottom',panel.grid.minor=element_blank(),
                                     plot.caption=element_text(hjust=0),strip.text=element_text(face='bold'))
ggsave('output/figures/experimental_vs_simulation.png',comparison_plot,width=10.5,height=7.5,dpi=160)

# Retained episodes: aggregate first within seed, then across seeds.
trajectory <- list(); blocks <- list()
for (game in games) for (treatment in treatments) {
  folder <- file.path('output','baseline',paste0(game,'_',treatment))
  g <- read.csv(file.path(folder,'group_round.csv'))
  stopifnot(nrow(g)==32*40*20, !anyDuplicated(g[c('run_id','revision_step','round')]))
  stopifnot(all(table(g$run_id)==40*20), all(g$round %in% 1:20))
  stopifnot(all(g$group_relative_contribution >= 0 & g$group_relative_contribution <= 1))
  metric <- if (game == 'linear') 'group_relative_contribution' else 'success'
  if (game == 'threshold') {
    # pandas writes Boolean success as True/False; R does not parse that case automatically.
    stopifnot(all(g$success %in% c('True','False','1','0')))
    g$success <- as.numeric(g$success %in% c('True','1'))
  }
  seed_round <- aggregate(g[[metric]],g[c('seed','round')],mean)
  names(seed_round)[3] <- 'value'
  sim_round <- aggregate(value~round,seed_round,mean)
  sim_round$source <- 'Simulation: retained episodes'
  e <- experimental_round[experimental_round$game==game & experimental_round$Treatment==treatment, ]
  emp_round <- aggregate(e[[metric]],list(round=e$Round),mean)
  names(emp_round)[2] <- 'value'
  emp_round$source <- 'Experiment'
  d <- rbind(sim_round,emp_round)
  d$game <- game;d$treatment <- treatment;d$metric <- metric
  trajectory[[length(trajectory)+1]] <- d
  b <- read.csv(file.path(folder,'learning_blocks.csv'))
  stopifnot(!anyDuplicated(b[c('seed','step')]), all(b$acceptance_rate>=0 & b$acceptance_rate<=1))
  blocks[[length(blocks)+1]] <- b
}
trajectory <- do.call(rbind,trajectory)
trajectory$treatment <- factor(trajectory$treatment,levels=treatments)
write.csv(trajectory,'output/round_trajectory_comparison.csv',row.names=FALSE)
p <- ggplot(trajectory,aes(round,value,color=source)) + geom_line(linewidth=.7) +
  facet_grid(game~treatment,scales='free_y') +
  scale_color_manual(values=c('Experiment'='#176B70','Simulation: retained episodes'='#B24D32')) +
  scale_x_continuous(breaks=c(1,5,10,15,20)) +
  labs(title='Within-episode patterns',x='Round within a 20-round episode',y='Linear: relative contribution; threshold: success',color=NULL,
       caption='Simulation curves average retained fixed-strategy episodes. Revision steps are a separate time scale.') +
  theme_minimal(base_size=12) + theme(legend.position='bottom',panel.grid.minor=element_blank())
ggsave('output/figures/round_trajectories.png',p,width=11,height=6.5,dpi=160)

blocks <- do.call(rbind,blocks)
block_mean <- aggregate(surplus~game+treatment+step,blocks,mean)
block_low <- aggregate(surplus~game+treatment+step,blocks,function(x) unname(quantile(x,.1)))
block_high <- aggregate(surplus~game+treatment+step,blocks,function(x) unname(quantile(x,.9)))
stopifnot(identical(block_mean[1:3],block_low[1:3]),identical(block_mean[1:3],block_high[1:3]))
block_mean$p10 <- block_low$surplus;block_mean$p90 <- block_high$surplus
block_mean$treatment <- factor(block_mean$treatment,levels=treatments)
write.csv(block_mean,'output/learning_diagnostics.csv',row.names=FALSE)
p <- ggplot(block_mean,aes(step,surplus)) +
  geom_ribbon(aes(ymin=p10,ymax=p90),fill='#176B70',alpha=.2) + geom_line(color='#176B70') +
  geom_vline(xintercept=2000,linetype=2,color='gray40') + facet_grid(game~treatment,scales='free_y') +
  labs(title='Learning diagnostics: finite-chain drift and dispersion',x='Strategy revision step',y='Mean surplus per 250-step block',
       caption='Band: 10th-90th percentile across independent chains, not a confidence interval. Dashed line: end of warm-up.') +
  theme_minimal(base_size=12) + theme(panel.grid.minor=element_blank())
ggsave('output/figures/learning_diagnostics.png',p,width=11,height=6.5,dpi=160)

if ('--sensitivity' %in% commandArgs(trailingOnly=TRUE)) {
  variants <- c('resolution25','minimum_signal','initial_zero','initial_full','longer','no_fairness')
  tables <- list(summary[, names(summarize_chains(baseline))])
  paired <- list()
  for (variant in variants) {
    d <- read_suite(variant)
    stopifnot(nrow(d)==96)
    tables[[length(tables)+1]] <- summarize_chains(d)
    # Same seed numbers support paired diagnostics, though RNG consumption can differ by variant.
    keys <- c('game','treatment','seed')
    stopifnot(!anyDuplicated(d[keys]),!anyDuplicated(baseline[keys]))
    joined <- merge(d,baseline,by=keys,suffixes=c('_variant','_baseline'),all.x=TRUE)
    stopifnot(nrow(joined)==nrow(d),!anyNA(joined$run_id_baseline))
    for (game in games) for (treatment in treatments) for (metric in metrics) {
      if (game=='linear' && metric=='success') next
      z <- joined[joined$game==game & joined$treatment==treatment, ]
      delta <- z[[paste0(metric,'_variant')]] - z[[paste0(metric,'_baseline')]]
      paired[[length(paired)+1]] <- data.frame(experiment=variant,game=game,treatment=treatment,metric=metric,
        mean_difference=mean(delta),paired_mc_se=sd(delta)/sqrt(length(delta)),n_seeds=length(delta),
        n_matched=length(delta),join_match_rate=1,join_row_inflation=0)
    }
  }
  sensitivity <- do.call(rbind,tables)
  write.csv(sensitivity,'output/sensitivity_summary.csv',row.names=FALSE)
  write.csv(do.call(rbind,paired),'output/sensitivity_paired_differences.csv',row.names=FALSE)
  d <- sensitivity[sensitivity$metric=='surplus', ]
  d$experiment <- factor(d$experiment,levels=c('baseline',variants))
  d$treatment <- factor(d$treatment,levels=treatments)
  p <- ggplot(d,aes(experiment,simulation_mean)) +
    geom_errorbar(aes(ymin=mc_lower,ymax=mc_upper),width=.15,color='#176B70') +
    geom_point(color='#176B70',size=2) + facet_wrap(~game+treatment,scales='free',ncol=3) +
    coord_flip() + labs(title='Sensitivity checks: no settings selected to improve fit',x=NULL,y='Surplus (mean and 95% Monte Carlo CI)',
      caption='Baseline: 32 seeds. Alternatives: 16 seeds. Longer: 12,000 revisions, retain the final 4,000; others: 6,000 revisions.') +
    theme_minimal(base_size=11) + theme(panel.grid.minor=element_blank())
  ggsave('output/figures/sensitivity_checks.png',p,width=11,height=7.5,dpi=160)
}
capture.output(sessionInfo(),file='output/R_session_info.txt')
print(summary[c('game','treatment','metric','experimental_mean','simulation_mean','mc_lower','mc_upper')],row.names=FALSE)
cat('\nAnalysis complete; outputs saved under output/.\n')
