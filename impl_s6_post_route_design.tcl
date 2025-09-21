# adapted from: https://github.com/riadhbenabdelhamid/BRISKI/blob/main/hardware/vivado-impl/compile-scripts/post_route.tcl
# tcl guide: https://docs.xilinx.com/r/2021.1-English/ug835-vivado-tcl-commands/route_design

source ./scripts/color_func.tcl

# * get start time
set start_time [clock seconds]


# * open previous checkpoint
print_yellow "reading checkpoint: ${name_chkp_impl5}"
open_checkpoint ${dir_chkp}/${name_chkp_impl5}.dcp
open_checkpoint ${dir_chkp}/impl_s5_route_design_run2_vcu118_13500x2_150mhz_no_pblks.dcp

# get worst negative slack
print_yellow "print value of WNS"
set WNS [ get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup] ]
print_blue "original WNS = $WNS"

if {$WNS < 0.000} {
    print_yellow "running phys_opt_design with directive: AggressiveExplore"
    phys_opt_design -directive AggressiveExplore
    report_timing_summary -check_timing_verbose -delay_type min_max -max_paths 10 -report_unconstrained -input_pins -routable_nets -file ${dir_rpt}/${name_rpt_impl6}_timing_AggressiveExplore.rpt
    print_yellow "running phys_opt_design with directive: AlternateReplication"
    phys_opt_design -directive AlternateReplication
    report_timing_summary -check_timing_verbose -delay_type min_max -max_paths 10 -report_unconstrained -input_pins -routable_nets -file ${dir_rpt}/${name_rpt_impl6}_timing_AlternateReplication.rpt
    print_yellow "running phys_opt_design with directive: Explore"
    phys_opt_design -directive Explore
    report_timing_summary -check_timing_verbose -delay_type min_max -max_paths 10 -report_unconstrained -input_pins -routable_nets -file ${dir_rpt}/${name_rpt_impl6}_timing_Explore.rpt
    print_yellow "running phys_opt_design with directive: AggressiveFanoutOpt"
    phys_opt_design -directive AggressiveFanoutOpt
    report_timing_summary -check_timing_verbose -delay_type min_max -max_paths 10 -report_unconstrained -input_pins -routable_nets -file ${dir_rpt}/${name_rpt_impl6}_timing_AggressiveFanoutOpt.rpt
}

set WNS [ get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup] ]
print_blue "updated WNS = $WNS"

# setting up iterative optimization loop
set ITERATIONS 12
set TNS_PREV 0
set WNS_SRCH_STR "WNS="
set TNS_SRCH_STR "TNS="

if {$WNS < 0.000} {

    set TNS [ exec grep $TNS_SRCH_STR vivado.log | tail -1 | sed -n -e "s/^.*$TNS_SRCH_STR//p" | cut -d\  -f 1]
    set TNS_ITER_PREV $TNS

    for {set i 0} {$i < $ITERATIONS} {incr i} {
        phys_opt_design -directive AlternateReplication
        set WNS [ exec grep $WNS_SRCH_STR vivado.log | tail -1 | sed -n -e "s/^.*$WNS_SRCH_STR//p" | cut -d\  -f 1]
        set TNS [ exec grep $TNS_SRCH_STR vivado.log | tail -1 | sed -n -e "s/^.*$TNS_SRCH_STR//p" | cut -d\  -f 1]
        if {($TNS == $TNS_PREV && $i > 0) || $WNS >= 0.000} {
            break
        }
        set TNS_PREV $TNS

        phys_opt_design -directive AggressiveFanoutOpt
        set WNS [ exec grep $WNS_SRCH_STR vivado.log | tail -1 | sed -n -e "s/^.*$WNS_SRCH_STR//p" | cut -d\  -f 1]
        set TNS [ exec grep $TNS_SRCH_STR vivado.log | tail -1 | sed -n -e "s/^.*$TNS_SRCH_STR//p" | cut -d\  -f 1]
        if {($TNS == $TNS_PREV && $i > 0) || $WNS >= 0.000} {
            break
        }
        set TNS_PREV $TNS

        phys_opt_design -directive AggressiveExplore
        set WNS [ exec grep $WNS_SRCH_STR vivado.log | tail -1 | sed -n -e "s/^.*$WNS_SRCH_STR//p" | cut -d\  -f 1]
        set TNS [ exec grep $TNS_SRCH_STR vivado.log | tail -1 | sed -n -e "s/^.*$TNS_SRCH_STR//p" | cut -d\  -f 1]
        if {($TNS == $TNS_PREV) || $WNS >= 0.000} {
            break
        }
        set TNS_PREV $TNS

        if {($TNS_PREV == $TNS_ITER_PREV) || $WNS >= 0.000} {
            break
        }
    }
}

# * write reports
print_yellow "writing reports: post implementation post_route_design"
# timing reports
print_blue "writing report_timing_summary"
report_timing_summary -check_timing_verbose -delay_type min_max -max_paths 10 -report_unconstrained -input_pins -routable_nets -file ${dir_rpt}/${name_rpt_impl6}_timing_summary.rpt
print_blue "writing report_bus_skew"
report_bus_skew -sort_by_slack -delay_type min_max -max_paths 10 -input_pins -file ${dir_rpt}/${name_rpt_impl6}_bus_skew.rpt
print_blue "writing report_timing"
report_timing -delay_type min_max -sort_by group -input_pins -routable_nets -file ${dir_rpt}/${name_rpt_impl6}_timing.rpt
print_blue "writing check_timing"
check_timing -verbose -file ${dir_rpt}/${name_rpt_impl6}_check_timing.rpt
print_blue "writing report_config_timing"
report_config_timing -all -file ${dir_rpt}/${name_rpt_impl6}_config_timing.rpt
print_blue "writing create_slack_histogram"
create_slack_histogram -significant_digits 3 -file ${dir_rpt}/${name_rpt_impl6}_create_slack_histogram.rpt
print_blue "writing report_clock_interaction"
report_clock_interaction -delay_type min_max -significant_digits 3 -file ${dir_rpt}/${name_rpt_impl6}_clock_interaction.rpt
print_blue "writing report_cdc"
report_cdc -file ${dir_rpt}/${name_rpt_impl6}_cdc.rpt
print_blue "writing report_exceptions"
report_exceptions -coverage -file ${dir_rpt}/${name_rpt_impl6}_exceptions.rpt
print_blue "writing report_clock_networks"
report_clock_networks -file ${dir_rpt}/${name_rpt_impl6}_clock_networks.rpt
print_blue "writing report_pulse_width"
report_pulse_width -significant_digits 3 -file ${dir_rpt}/${name_rpt_impl6}_pulse_width.rpt
print_blue "writing report_clock_utilization"
report_clock_utilization -file ${dir_rpt}/${name_rpt_impl6}_clock_utilization.rpt
# methodology reports
print_blue "writing report_methodology"
report_methodology -file ${dir_rpt}/${name_rpt_impl6}_methodology.rpt
# drc reports
print_blue "writing report_drc"
report_drc -ruledecks {default opt_checks placer_checks router_checks bitstream_checks incr_eco_checks eco_checks abs_checks} -file ${dir_rpt}/${name_rpt_impl6}_drc.rpt
# popwer reports
print_blue "writing report_power"
report_power -file ${dir_rpt}/${name_rpt_impl6}_power.rpt
# routing reports
print_blue "writing report_route_status"
report_route_status -show_all -file ${dir_rpt}/${name_rpt_impl6}_route_status.rpt
# utilization reports
print_blue "writing report_ip_status"
report_ip_status -file ${dir_rpt}/${name_rpt_impl6}_ip_status.rpt
print_blue "writing report_ram_utilization"
report_ram_utilization -file ${dir_rpt}/${name_rpt_impl6}_ram_utilization.rpt
print_blue "writing report_utilization"
report_utilization -file ${dir_rpt}/${name_rpt_impl6}_utilization.rpt
# print_blue "writing report_utilization -hierarchical"
# report_utilization -hierarchical -file ${dir_rpt}/${name_rpt_impl6}_utilization_hierarchical.rpt



# * get elapsed time
# get end time
set end_time [clock seconds]
# calculate elapsed time in seconds
set elapsed_time [expr {$end_time - $start_time}]
# convert seconds to dd:hh:mm:ss format
set days [expr {$elapsed_time / (24 * 3600)}]
set rem_sec [expr {$elapsed_time % (24 * 3600)}]
set hours [expr {$rem_sec / 3600}]
set rem_sec [expr {$rem_sec % 3600}]
set minutes [expr {$rem_sec / 60}]
set seconds [expr {$rem_sec % 60}]
# print total time taken
print_blue "Simulation started at:  [clock format $start_time -format "%d-%b-%Y - %I:%M:%S - %p"]"
print_blue "Simulation ended at:    [clock format $end_time -format "%d-%b-%Y - %I:%M:%S - %p"]"
print_green "Implementation (post_route_design) time taken: [format \"%02d:%02d:%02d:%02d\" $days $hours $minutes $seconds]"
