/* This file is (C) copyright 2001 Software Improvements, Pty Ltd */

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
#include <common/barcode.h>
#include <common/voter_electorate.h>
#include "input.h"
#include "confirm_vote.h"
#include "verify_barcode.h"
#include "vote_in_progress.h"
#include "message.h"
#include "commit.h"
#include "audio.h"

/* SIPL 2014-03-07 there are now four screens that serve as a type
   of "confirmation screen", and it is necessary to keep track of
   which one is currently being displayed.
   The variable confirmation_screen_mode starts off
   (in the function confirm_and_commit_vote()) being assigned the
   value FORMAL_CONFIRMATION, and will be changed based on
   subsequent formality checks and keystrokes.
   Pressing the SELECT key on either FORMAL_CONFIRMATION or
   INFORMAL_CONFIRMATION goes to the hidden vote screen; this
   does not change the value of confirmation_screen_mode.
*/
static enum confirmation_screen_mode {
	/* Ballot is formal */
	FORMAL_CONFIRMATION,
	/* Just come from an informal ballot */
	INFORMAL_STAGE_1,
	/* User pressed DOWN while on INFORMAL_STAGE_1 */
	INFORMAL_STAGE_2,
	/* User pressed SELECT while on INFORMAL_STAGE_2 */
	INFORMAL_CONFIRMATION,
} confirmation_screen_mode;

static void draw_candidates(unsigned int top,
			    const struct preference_set *vote)
{
	unsigned int i, x, y;
	struct image *candimg, *prefimg;
	const struct electorate *elec;

	x = 0;
	y = top;
	elec = get_voter_electorate();

	for (i = 0; i < vote->num_preferences; i++) {
		/* Fetch preference image for this candidate (1-based). */
		prefimg = get_preference_image(elec->code, i+1);
		/* Fetch candidate image */
		candimg = get_cand_with_group_img(elec->code,
						  vote->candidates[i]
						  .group_index,
						  vote->candidates[i]
						  .db_candidate_index);

		/* Are we going to go off the screen? */
		if (y + image_height(prefimg) >= get_screen_height()) {
			/* Move across one column */
			x += image_width(prefimg) + image_width(candimg);
			y = top;
		}

		/* Paste them side-by-side on the screen */
		paste_image(x, y, prefimg);
		paste_image(x + image_width(prefimg), y, candimg);

		/* Move down the screen (both images are same height) */
		y += image_height(prefimg);
	}
}


/* SIPL 2014-03-07 */
/* Draw the stage 1 informal screen */
static void format_informal_screen_stage_1(unsigned int language)
{
	unsigned int ypos;
	struct image *no_cands, *blank, *options;

	/* Screen consists of these three images */
	no_cands = get_message(language, MSG_NO_CANDIDATES_SELECTED);
	blank = get_message(language, MSG_CAST_BLANK_VOTE);
	options = get_message(language, MSG_OPTIONS_INFORMAL_STAGE_1);

	/* Start at centre of the screen, minus half their heights. */
	ypos = (get_screen_height()
		- image_height(no_cands)
		- image_height(blank)
		- image_height(options))/2;

	/* Paste them one under the other */
	paste_image(0, ypos, no_cands);
	ypos += image_height(no_cands);
	paste_image(0, ypos, blank);
	ypos += image_height(blank);
	paste_image(0, ypos, options);

	play_audio_loop(true, get_audio("informal_stage_1.raw"));
}

/* SIPL 2014-03-07 */
/* Draw the stage 2 informal screen */
static void format_informal_screen_stage_2(unsigned int language)
{
	unsigned int ypos;
	struct image *no_cands, *blank, *options;

	/* Screen consists of these three images */
	no_cands = get_message(language, MSG_NO_CANDIDATES_SELECTED);
	blank = get_message(language, MSG_CAST_BLANK_VOTE);
	options = get_message(language, MSG_OPTIONS_INFORMAL_STAGE_2);

	/* Start at centre of the screen, minus half their heights. */
	ypos = (get_screen_height()
		- image_height(no_cands)
		- image_height(blank)
		- image_height(options))/2;

	/* Paste them one under the other */
	paste_image(0, ypos, no_cands);
	ypos += image_height(no_cands);
	paste_image(0, ypos, blank);
	ypos += image_height(blank);
	paste_image(0, ypos, options);

	play_audio_loop(true, get_audio("informal_stage_2.raw"));
}

/* SIPL 2014-03-07 */
/* This was format_informal_screen(). Now that there are multiple
   versions of informal confirmation screen, it has been renamed
   as format_informal_screen_final(). */
static void format_informal_screen_final(unsigned int language)
{
	unsigned int ypos;
	struct image *no_cands, *informal, *undo, *hide;

	/* Screen consists of these four images */
	no_cands = get_message(language, MSG_NO_CANDIDATES_SELECTED);
	informal = get_message(language, MSG_YOUR_VOTE_WILL_BE_INFORMAL);
	undo = get_message(language, MSG_PRESS_UNDO_TO_RETURN);
	hide = get_message(language, MSG_PRESS_SELECT_TO_HIDE_INFORMAL);

	/* Start at centre of the screen, minus half their heights. */
	ypos = (get_screen_height()
		- image_height(no_cands)
		- image_height(informal)
		- image_height(undo)
		- image_height(hide))/2;

	/* Paste them one under the other */
	paste_image(0, ypos, no_cands);
	ypos += image_height(no_cands);
	paste_image(0, ypos, informal);
	ypos += image_height(informal);
	paste_image(0, ypos, undo);
	ypos += image_height(undo);
	paste_image(0, ypos, hide);

	play_audio_loop(true, get_audio("informal.raw"));
	confirmation_screen_mode = INFORMAL_CONFIRMATION;
}


/* Draw the informal confirmation screen */
/* SIPL 2014-03-07 Support the different versions of the confirmation
   screen. */
static void format_informal_screen(unsigned int language)
{
	/* As noted in confirm_and_commit_vote(), confirmation_screen_mode
	   starts off with the value FORMAL_CONFIRMATION. So if we
	   reach here with that value, switch mode to INFORMAL_STAGE_1. */
	if (confirmation_screen_mode == FORMAL_CONFIRMATION)
		confirmation_screen_mode = INFORMAL_STAGE_1;

	/* Dispatch to the appropriate screen .*/
	switch (confirmation_screen_mode) {
	case INFORMAL_STAGE_1:
		format_informal_screen_stage_1(language);
		break;
	case INFORMAL_STAGE_2:
		format_informal_screen_stage_2(language);
		break;
	case INFORMAL_CONFIRMATION:
		format_informal_screen_final(language);
		break;

	default:
		/* Should never happen */
		display_error(ERR_INTERNAL);
		break;
	}
}

/* Play audio messages */
static void play_candidates_in_loop(const struct electorate *elec,
				    const struct preference_set *vip)
{
	unsigned int i;
	struct audio *audio[1 + vip->num_preferences*3 + 1];

	/* Start of spiel... */
	audio[0] = get_audio("formal.raw");
	for (i = 0; i < vip->num_preferences; i++) {
		/* Preference number, candidate name, group name */
		audio[1 + i*3] = get_audio("numbers/%u.raw", i+1);
		audio[1 + i*3 + 1]
			= get_audio("electorates/%u/%u/%u.raw",
				    elec->code,
				    vip->candidates[i].group_index,
				    vip->candidates[i].db_candidate_index);
		/* SIPL 2014-05-23 Use the original group audio (i.e.,
		   without any group letter) on the confirmation screen. */
		audio[1 + i*3+2] 
		        = get_audio("electorates/%u/%u_original.raw",
				    elec->code,
				    vip->candidates[i].group_index);
	}
	/* ... end of spiel */
	audio[1 + i*3] = get_audio("formal2.raw");

	play_multiaudio_loop(true, 1 + vip->num_preferences*3 + 1, audio);
}

/* DDS3.2.24: Display Confirmation Screen */
/* SIPL 2014-03-07 Now support multiple types of confirmation screen. */
static void format_confirm_screen(unsigned int language)
{
	const struct preference_set *vote;
	struct image *img;
	unsigned int ypos = 0;

	/* Figure out what they voted */
	vote = get_vote_in_progress();

	/* Draw background */
	paste_image(0, 0, get_message(language, MSG_BACKGROUND));

	/* Informal screen looks different */
	if (vote->num_preferences == 0) {
		format_informal_screen(language);
		/* SIPL 2014-03-07 format_informal_screen will set
		   confirmation_screen_mode if it needs to. */
		return;
	}

	/* Formal vote: paste messages at top, candidates underneath. */
	img = get_message(language, MSG_CHECK_YOUR_VOTE);
	paste_image(0, ypos, img);
	ypos += image_height(img);
	img = get_message(language, MSG_SWIPE_BARCODE_TO_CONFIRM);
	paste_image(0, ypos, img);
	ypos += image_height(img);
	img = get_message(language, MSG_PRESS_SELECT_TO_HIDE);
	paste_image(0, ypos, img);
	ypos += image_height(img);
	draw_candidates(ypos, vote);

	/* Play audio messages */
	play_candidates_in_loop(get_voter_electorate(), vote);
	/* SIPL 2014-03-07 We just drew the formal confirmation
	   screen, so set confirmation_screen_mode accordingly. Note
	   that confirm_and_commit_vote() happens has already done
	   this, but only so that confirmation_screen_mode has an
	   initial value. */
	confirmation_screen_mode = FORMAL_CONFIRMATION;
}

/* DDS3.2.22: Formate Hidden Vote Screen */
static void format_hidden_vote_screen(unsigned int language)
{
	unsigned int ypos;
	struct image *hidden, *confirm;

	/* Draw background */
	paste_image(0, 0, get_message(language, MSG_BACKGROUND));

	hidden = get_message(language, MSG_YOUR_VOTE_HAS_BEEN_HIDDEN);
	confirm = get_message(language, MSG_SWIPE_BARCODE_TO_CONFIRM);

	/* Draw images in centre of screen */
	ypos = (get_screen_height()
		- image_height(hidden)
		- image_height(confirm))/2;
	paste_image(0, ypos, hidden);
	ypos += image_height(hidden);
	paste_image(0, ypos, confirm);
	
	/* Play audio message */
	play_audio_loop(true, get_audio("hidden.raw"));

}

/* DDS3.2.22: Confirm and Commit Vote */
/* SIPL 2014-03-19
   The return value indicates whether the user wishes to
   continue voting, i.e.:
   true:  user has chosen to return to the ballot paper
   false: user has chosen to commit their vote as it stands
   SIPL 2014-03-19
   This function now supports the multiple-stage informal
   confirmation process. The meaning of keystrokes/barcode swipes is
   now screen-dependent, hence the various second-level "switch"
   statements.
*/
bool confirm_and_commit_vote(unsigned int language)
{
	struct barcode bc;
	
	/* SIPL 2014-03-19
	   An initial value is needed for confirmation_screen_mode;
	   this should not be a value
           "in the middle" of the flow of screens so as not to
	   "confuse" the logic of format_informal_screen(), so
	   start by assuming the ballot is formal.
	   If this line is changed, also check format_informal_screen().
	*/
	confirmation_screen_mode = FORMAL_CONFIRMATION;

	format_confirm_screen(language);

	for (;;) {
		switch (get_keystroke_or_barcode(&bc)) {
		case INPUT_SELECT:
			/* On the two "final" confirmation screens,
			 hide vote. On INFORMAL_STAGE_2, switch to
			 INFORMAL_CONFIRMATION and update the screen. */
			switch (confirmation_screen_mode) {
			case FORMAL_CONFIRMATION:
			case INFORMAL_CONFIRMATION:
				format_hidden_vote_screen(language);
				break;
			case INFORMAL_STAGE_2:
				confirmation_screen_mode =
					INFORMAL_CONFIRMATION;
				format_confirm_screen(language);
				break;
			default:
				break;
			}
			break;
		case INPUT_DOWN:
			/* On INFORMAL_STAGE_1, switch to INFORMAL_STAGE_2
			   and update the screen. */
			if (confirmation_screen_mode == INFORMAL_STAGE_1) {
				confirmation_screen_mode = INFORMAL_STAGE_2;
				format_confirm_screen(language);
			}
			break;
		case INPUT_UP:
			/* On INFORMAL_STAGE_1 and INFORMAL_STAGE_2,
			   treat INPUT_UP like INPUT_UNDO, i.e.,
			   continue voting. */
			if ((confirmation_screen_mode == INFORMAL_STAGE_1) ||
			    (confirmation_screen_mode == INFORMAL_STAGE_2))
				return true;
			break;
		case INPUT_UNDO:
			/* Continue voting */
			return true;
			break;
		case INPUT_VOLUME_UP:
			increase_volume();
			break;
		case INPUT_VOLUME_DOWN:
			decrease_volume();
			break;
		case INPUT_BARCODE:
			/* Only consider a barcode swipe on the two
			   main confirmation screens, i.e.,
			   FORMAL_CONFIRMATION and INFORMAL_CONFIRMATION.
			   NB: these possibilities also cover
			   the "hidden vote" screen.
			*/
			if ((confirmation_screen_mode ==
			     FORMAL_CONFIRMATION) ||
			    (confirmation_screen_mode ==
			     INFORMAL_CONFIRMATION)) {
				/* If barcode OK, commit the vote */
				if (verify_barcode(&bc)) {
					commit_vote(&bc);
					/* Do not continue voting */
					return false;
				}
			}
			break;

		default:
			/* Ignore other keys */
			break;
		}
	}
}
