/*
 * NI general-purpose counter example.  Configures the counter to
 * start simple event counting.  The counter's value can be read
 * with the inp demo.  Different clock sources can be chosen
 * with the choose_clock demo.
 * Part of Comedilib
 *
 * Copyright (c) 2007 Frank Mori Hess <fmhess@users.sourceforge.net>
 *
 * This file may be freely modified, distributed, and combined with
 * other software, as long as proper attribution is given in the
 * source code.
 */
/*
 * Requirements:  A board with a National Instruments general-purpose
 * counter, and comedi driver version 0.7.74 or newer.
 */

#define _GNU_SOURCE

#include <stdio.h>
#include <comedilib.h>
#include <math.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <getopt.h>
#include <ctype.h>
#include "examples.h"

int ni_gpct_start_simple_event_counting(comedi_t *device, unsigned subdevice, unsigned period_ns, unsigned up_time_ns)
{
	int retval;
	lsampl_t counter_mode;

	retval = reset_counter(device, subdevice);
	if(retval < 0) return retval;

	retval = set_gate_source(device, subdevice, 0, NI_GPCT_DISABLED_GATE_SELECT | CR_EDGE);
	if(retval < 0) return retval;
	retval = set_gate_source(device, subdevice, 1, NI_GPCT_DISABLED_GATE_SELECT | CR_EDGE);
	if(retval < 0)
	{
		fprintf(stderr, "Failed to set second gate source.  This is expected for older boards (e-series, etc.)\n"
			"that don't have a second gate.\n");
	}

	counter_mode = NI_GPCT_COUNTING_MODE_NORMAL_BITS;
	// output pulse on terminal count (doesn't really matter for this application)
	counter_mode |= NI_GPCT_OUTPUT_TC_PULSE_BITS;
	/* Don't alternate the reload source between the load a and load b registers.
		Doesn't really matter here, since we aren't going to be reloading the counter.
	*/
	counter_mode |= NI_GPCT_RELOAD_SOURCE_FIXED_BITS;
	// count up
	counter_mode |= NI_GPCT_COUNTING_DIRECTION_UP_BITS;
	// don't stop on terminal count
	counter_mode |= NI_GPCT_STOP_ON_GATE_BITS;
	// don't disarm on terminal count or gate signal
	counter_mode |= NI_GPCT_NO_HARDWARE_DISARM_BITS;
	retval = set_counter_mode(device, subdevice, counter_mode);
	if(retval < 0) return retval;

	retval = arm(device, subdevice, NI_GPCT_ARM_IMMEDIATE);
	if(retval < 0) return retval;

	return 0;
}

int main(int argc, char *argv[])
{
	comedi_t *device;
	unsigned up_time;
	unsigned period_ns;
	int retval;
	struct parsed_options options;

	init_parsed_options(&options);
	options.value = -1.;
	parse_options(&options, argc, argv);
	period_ns = lrint(1e9 / options.freq);
	if(options.value < 0.)
		up_time = period_ns / 2;
	else
		up_time = lrint(options.value);
	device = comedi_open(options.filename);
	if(!device)
	{
		comedi_perror(options.filename);
		exit(-1);
	}
	/*FIXME: check that device is counter */
	printf("Initiating simple event counting on subdevice %d.\n", options.subdevice);

	retval = ni_gpct_start_simple_event_counting(device, options.subdevice, period_ns, up_time);
	if(retval < 0) return retval;
	return 0;
}
