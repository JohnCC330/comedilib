
#include <stdio.h>
#include <comedilib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <getopt.h>
#include <ctype.h>
#include <math.h>
#include <sys/time.h>
#include <string.h>
#include "comedi_test.h"


int test_insn_read_time(void)
{
	comedi_insn insn[3];
	comedi_insnlist il;
	struct timeval t1,t2;
	lsampl_t data;
	int save_errno;
	int ret;

	printf("rev 1\n");

	memset(&il,0,sizeof(il));
	memset(insn,0,sizeof(insn));

	il.n_insns = 3;
	il.insns = insn;

	insn[0].insn = INSN_GTOD;
	insn[0].n=2;
	insn[0].data = (void *)&t1;

	insn[1].subdev = subdevice;
	insn[1].insn = INSN_READ;
	insn[1].n = 1;
	insn[1].chanspec = CR_PACK(0,0,0);
	insn[1].data = &data;

	insn[2].insn = INSN_GTOD;
	insn[2].n=2;
	insn[2].data = (void *)&t2;

	ret = comedi_do_insnlist(device,&il);
	save_errno = errno;

	printf("comedi_do_insn: %d\n",ret);
	if(ret<0){
		printf("W: comedi_do_insn: errno=%d %s\n",save_errno,strerror(save_errno));
	}
	if(ret<2){
		printf("W: comedi_do_insn: returned %d (expected 3)\n",ret);
	}

	printf("read time: %ld us\n",
		(t2.tv_sec-t1.tv_sec)*1000000+(t2.tv_usec-t1.tv_usec));


	return 0;
}
