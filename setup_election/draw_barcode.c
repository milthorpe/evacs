/* This file is (C) copyright 2001 Software Improvements, Pty Ltd.
   Based on prototype prototypes/codegen/bar_encode.c by:
	Copyright (C) Andrew Tridgell 2001
*/

/* This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <limits.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <barcode.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <common/evacs.h>
#include <common/barcode.h>
#include "draw_barcode.h"


/* Barcode page size in 1/72 of an inch: fits on 1/8 A4 page (ie. A7) */
#define BARCODE_PAGE_WIDTH 297
#define BARCODE_PAGE_HEIGHT 210

/* How tall is the barcode in 1/72 of an inch */
/*
#define BARCODE_HEIGHT 50
*/
#define BARCODE_HEIGHT 60

/* How far above barcode is baseline of writing? */
#define BARCODE_TOP_MARGIN 5

/* Distance from the sides (1/72 of an inch) */
/*
#define BARCODE_SIDE_MARGIN 13
*/
#define BARCODE_SIDE_MARGIN 63
#define ASCII_STRING_HEIGHT 15
#define CENTRE_ADJUST 5 

/* How far off the bottom? */
#define BARCODE_BOTTOM_MARGIN 10

/* Fontsize for Electorate Name and Polling Place Name */
#define ENAME_FONTSIZE 12
#define PPNAME_FONTSIZE 10

/* SIPL 2014-06-02 Added shrinktofit function to support long
   electorate and polling place names.
   Use is:
      (Name to print) 171 shrinktofit
   It draws the text argument at the current position, shrinking
   it horizontally (only if necessary) to fit in the specified width. */
/* Postscript headers and tailers */
#define FILE_HEADER							\
	"%%!PS-Adobe-2.0 EPSF-2.0\n"					\
	"%%%%Creator: Software Improvements: draw_barcode (GPL)\n"	\
	"%%%%Orientation: Portrait\n"					\
	"%%%%BoundingBox: %u %u %u %u\n"				\
	"%%%%Pages: 0\n"						\
	"%%%%Magnification: 1.0000\n"					\
	"%%%%EndComments\n"						\
	"%% text width --\n"						\
	"/shrinktofit {\n"						\
	"  0 begin\n"							\
	"    /maxtextwidth exch def\n"					\
	"    /texttofit exch def\n"					\
	"    gsave\n"							\
	"      texttofit stringwidth pop maxtextwidth gt\n"		\
	"      { maxtextwidth texttofit stringwidth pop div 1 scale }\n" \
	"      if\n"							\
	"      texttofit show\n"					\
	"    grestore\n"						\
	"  end } def\n"						\
	"/shrinktofit load 0 2 dict put\n"

#define FILE_TAILER							\
	"showpage\n"							\
	"%%Trailer\n"

/* DDS3.2.1: Draw Polling Place Label */
/* Returns Polling Place Label to be inserted (must be freed by caller) */
/* SIPL 2014-05-27 The label has been moved to the left-hand side,
   directly underneath the electorate name. Horizontal shrinking
   is now applied (if necessary) using shrinktofit.
*/
static char *draw_pp_label(const char *ppname)
{
	/* X offset is right side - side margin - stringwidth */
	/* Y offset is barcode height + margin */
	return sprintf_malloc("/Helvetica findfont %u scalefont setfont"
			      " (%s) %u %u"
			      " moveto %u shrinktofit\n",
			      PPNAME_FONTSIZE,
			      ppname,
			      BARCODE_SIDE_MARGIN,
			      BARCODE_HEIGHT
			      + BARCODE_TOP_MARGIN + BARCODE_BOTTOM_MARGIN + ASCII_STRING_HEIGHT,
			      BARCODE_PAGE_WIDTH - (BARCODE_SIDE_MARGIN * 2));
}

/* DDS3.2.1: Draw Electorate Label */
/* Returns Electorate Label to be inserted (must be freed by caller) */
/* SIPL 2014-05-27 Move the electorate up, so that it is not on the
   same line as the polling place name. This allows for more space for the
   electorate name, without it bumping in to the polling place name.
   Horizontal shrinking is applied (if necessary) using shrinktofit.
*/
static char *draw_elec_label(const char *ename)
{
	/* X offset is right side - side margin - stringwidth */
	/* Y offset is barcode height + fontsize */
	return sprintf_malloc("/Helvetica-Bold findfont %u scalefont setfont"
			      " (%s) %u %u moveto %u shrinktofit\n",
			      ENAME_FONTSIZE,
			      ename,
			      BARCODE_SIDE_MARGIN,
			      BARCODE_HEIGHT
			      + BARCODE_TOP_MARGIN + BARCODE_BOTTOM_MARGIN + (ASCII_STRING_HEIGHT * 2),
			      BARCODE_PAGE_WIDTH - (BARCODE_SIDE_MARGIN * 2));
}

/* Returns Barcode Ascii Label to be inserted (must be freed by caller) */
static char *draw_ascii_label(struct barcode *bc)
{
	/* X offset is right side - side margin - stringwidth */
	/* Y offset is barcode height + fontsize */
	return sprintf_malloc("/Helvetica findfont %u scalefont setfont"
			      " (%s) %u %u moveto show\n",
			      PPNAME_FONTSIZE,
			      bc->ascii,
			      BARCODE_SIDE_MARGIN + CENTRE_ADJUST,
			      BARCODE_HEIGHT
			      + BARCODE_TOP_MARGIN + BARCODE_BOTTOM_MARGIN);
}

/* Do the actual drawing */
static void child_draw_barcode(int pipe_to_parent,
			       struct barcode *bc)
{
	FILE *toparent;

	toparent = fdopen(pipe_to_parent, "w");
	if (!toparent)
		bailout("Child could not fdopen to parent: %s\n",
			strerror(errno));

	/* Library call to encode ASCII value: seems to have built-in
           margin of 10. */
	if (Barcode_Encode_and_Print(bc->ascii,
				     toparent, 
				     BARCODE_PAGE_WIDTH
				     - 2*BARCODE_SIDE_MARGIN,
				     BARCODE_HEIGHT,
				     BARCODE_SIDE_MARGIN - 10,
				     BARCODE_BOTTOM_MARGIN - 10,
				     BARCODE_NO_CHECKSUM
				     | BARCODE_128B
				     | BARCODE_NO_ASCII
				     | BARCODE_OUT_NOHEADERS) != 0)
		bailout("Encoding of barcode for %s failed\n", bc->ascii);
	/* This also closes the underlying "pipe_to_parent" descriptor */
	fclose(toparent);
}

/* DDS3.2.1: Draw Barcode Bars */
static char *draw_barcode_bars(struct barcode *bc)
{
	char *image;
	int pipeends[2];
	pid_t child;
	size_t image_size, pos;
	ssize_t ret;
	int status;

	/* Fill in ASCII code for barcode */
	bar_encode_ascii(bc);

	/* Open pipe to talk to child */
	if (pipe(pipeends) != 0)
		bailout("Could not open pipes: %s\n", strerror(errno));

	child = fork();
	if (child == (pid_t)-1)
		bailout("Could not fork: %s\n", strerror(errno));

	if (child == 0) {
		/* This is the child. */
		close(pipeends[0]);
		child_draw_barcode(pipeends[1], bc);
		exit(0);
	}

	/* Read from pipe for child */
	/* Start with large, empty string */
	image_size = 1024;
	image = malloc(image_size);
	pos = 0;
	close(pipeends[1]);

	/* this used to be read_short, in safe.h */
	while ((ret = read(pipeends[0], image+pos, image_size - pos))>0){
		pos += ret;
		if (pos == image_size) {
			/* Enlarge */
			image_size *= 2;
			image = realloc(image, image_size);
		}
	}
	close(pipeends[0]);

	/* Terminate image string */
	image[pos] = '\0';

	/* Wait for child: check they exited cleanly. */
	waitpid(child, &status, 0);
	if (WIFEXITED(status) == 0 || WEXITSTATUS(status) != 0)
		bailout("Barcode generation child failed\n");

	return image;
}

/* DDS3.2.1: Draw Barcode */
char *draw_barcode(struct barcode *bc, const char *ppname, const char *ename)
{
	char *image, *ppimage, *elecimage;
  	char *ascii;

	image = draw_barcode_bars(bc);
	ppimage = draw_pp_label(ppname);
	elecimage = draw_elec_label(ename);
	ascii = draw_ascii_label(bc);

	/* Allocate space for all three together, and append labels. */
	image = realloc(image,
			strlen(image) + strlen(ppimage) + strlen(ascii) + strlen(elecimage)+1);
	strcat(image, ppimage);
	strcat(image, ascii);
	strcat(image, elecimage);

	/* No longer need intermediate images */
	free(ppimage);
	free(elecimage);
	free(ascii);
	return image;
}

/* DDS3.2.1: Print Page */
static void print_page(int fd, const char *page)
{
	write(fd, page, strlen(page));
}


/* DDS3.2.1: Print Full Page */
void print_full_page(const char *image, int bcfile)
{
	char header[sizeof(FILE_HEADER) + INT_CHARS*4];

	/* Create and write header */
	sprintf(header, FILE_HEADER,
		0, 0, BARCODE_PAGE_WIDTH, BARCODE_PAGE_HEIGHT);
	write(bcfile, header, strlen(header));

	/* Write image */
	print_page(bcfile, image);

	/* Write tailer */
	write(bcfile, FILE_TAILER, strlen(FILE_TAILER));
}
