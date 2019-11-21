#!/bin/bash

set -u

declare -i board=-1
declare -i BGOOD=(30 28 24 22 16 10) # no. of diamond cycles
declare -i BBLNK=(15 14 13 12 8 6)   # no. of checkerboard cycles
declare -i XCYCLE=(7 6 6 6 5 4)      # no. of cycles for timer

QUIT=0
TICK=3

# Location of "game over" in the end of the game
declare -i GAMEOVER_X=70 GAMEOVER_Y=23

declare -i GOOD=0 BAD=1 BLINK=2 EATEN=3
declare -i state=BAD
LMAN=('?' '%' '!')
CMAN=('?' '$' '!')
FMAN=('?' '#' '!')
NMAN=('?' '&' '!')
PMAN="0"

EATCHR=('2' '4' '8' 'X')
declare -i EATSCO=(200 400 800 1600)
declare -i FRUDSR=(16 16 16 16 16 18 18 18 18 18 20 20 20 20 20 22 22 22 22 22)
declare -i FRUDSC=(70 72 74 76 78 70 72 74 76 78 70 72 74 76 78 70 72 74 76 78)
declare -i FRUSCO=(100 300 500 700 1000 2000)
FRUCHR=('A' 'B' 'C' 'D' 'E' 'F')
frutbl=()
declare -i frucnt=-1 fruit=0 frutim fruon=0 frubrd FRUROW=12 FRUCOL=18
#
#	pacman works on a 24-cycle 'clock'. a timer is set to ensure that
#	each cycle takes cyctim one/sixtieths of a second.  cyctim is set to
#	seven on the first board, and decreases to four by the sixth board.
#	during each cycle, one movement is attempted for pacman and for each 
#	monster, and all decisions based on board state are made.
#
declare -i paccnt=3 # start with 3 pacmen
declare -i CMAR=37 RMAR=24

declare -i HALT=0 UP=1 DOWN=2 LEFT=4 RIGHT=8
declare -i DOT=16 EGZ=32 TUNNEL=64 DECISN=128
declare -i curdir=HALT newdir=HALT

declare -i mstate=()

declare -i timer=0 cycle=0 cyctim dcycle=0 statim=0
declare -i INICOL=18 INIROW=17 col row
declare -i atedot=0 score=0 extra=0 gamovr=0
declare -i CDOOR=18 RDOOR=8 # location where monsters start out from prison
declare -i LPRISC=17 LPRISR=10 # lefty starting location
declare -i CPRISC=19 CPRISR=10 # curly starting location
declare -i FPRISC=15 FPRISR=10 # fluffy starting location
declare -i NPRISC=21 NPRISR=10 # nellie starting location
#
#	                  -- relative speeds --
#
#	pacman moves at 100% of top speed normally, and at 75% when
#	he is eating dots. lefty moves at 92% of top speed and the other
#	three monsters at 83%. when traveling through a tunnel, the
#	monsters move at 50%. when they are being chased by pacman,
#	they all move at 67%.
#
#	move is the speed regulator for the pacman and the monsters.
#	top speed (100%) is defined as movement in every cycle
#	in the horizontal direction, and movement in every other
#	cycle in the vertical direction. (to correct for vt100 skew -
#	each screen position on the vt100 is approximately twice as high
#	as it is wide). other speeds are in relation to top speed. thus,
#	when it is necessary to determine if motion is allowed on the
#	current cycle, we first look at the current direction of motion
#	and see if that is allowed this cycle, and, if other than 100%
#	speed is desired, we also look at the appropriate entry in move to
#	see if motion for the desired speed is allowed. move is indexed by
#	cycle number (column) and by rate of speed (row).
#
#	the rows are defined as follows:
#			row 0 - 100% of top speed (up)
#			row 1 - 100% of top speed (down)
#			row 2 - 50% of top speed
#			row 3 - 100% of top speed (left)
#			row 4 - 92% of top speed
#			row 5 - 75% of top speed
#			row 6 - 83% of top speed
#			row 7 - 100% of top speed (right)
#			row 8 - 67% of top speed
declare -i move=(
0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 
0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 
1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 
1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
1 1 1 1 1 1 1 1 0 1 1 1 1 1 1 1 1 1 1 0 1 1 1 1 
0 1 1 1 1 0 1 1 0 1 1 1 1 0 1 1 0 1 1 1 1 0 1 1 
1 0 1 1 1 1 1 1 0 1 1 1 1 0 1 1 1 1 1 1 0 1 1 1 
1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
1 0 1 0 1 1 1 0 1 0 1 1 1 0 1 0 1 1 1 0 1 0 1 1
)

declare -i pacdsc=0 pacdsr=0 pacdsd=0
declare -i cdir crow ccol cprisn cdir
declare -i ldir lrow lcol lprisn ldir
declare -i fdir frow fcol fprisn fdir
declare -i ndir nrow ncol nprisn ndir

use_ascii=false

if $use_ascii; then
    DOOR="="
    DOTCHR="."
    EGZCHR="*"
    HORIZ="-"
    LLCOR="+"
    LRCOR="+"
    SPACE=" "
    TDOWN="+"
    TLEFT="+"
    TRIGHT="+"
    TUNCHR=":"
    ULCOR="+"
    URCOR="+"
    VERT="|"
    TOMBST="X"
    PREFIX=""
    SUFFIX=""
else
    DOOR="r"
    DOTCHR="~"
    EGZCHR="f"
    HORIZ="q"
    LLCOR="m"
    LRCOR="j"
    SPACE=" "
    TDOWN="w"
    TLEFT="u"
    TRIGHT="t"
    TUNCHR=":"
    ULCOR="l"
    URCOR="k"
    VERT="x"
    TOMBST="g"
    PREFIX='\e(0'
    SUFFIX='\e(B'
fi

maze=(
"$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$SPACE$SPACE$SPACE$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$URCOR"
"$VERT$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$VERT$SPACE$SPACE$SPACE$VERT$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$VERT"
"$VERT$EGZCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$VERT$SPACE$SPACE$SPACE$VERT$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$EGZCHR$VERT"
"$VERT$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$VERT"
"$VERT$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$VERT"
"$VERT$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$ULCOR$URCOR$DOTCHR$TRIGHT$HORIZ$HORIZ$HORIZ$HORIZ$TDOWN$HORIZ$TDOWN$HORIZ$HORIZ$HORIZ$HORIZ$TLEFT$DOTCHR$ULCOR$URCOR$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$VERT"
"$VERT$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$VERT$VERT$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$VERT$SPACE$VERT$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$VERT$VERT$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$VERT"
"$VERT$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$VERT$TRIGHT$HORIZ$HORIZ$HORIZ$HORIZ$TLEFT$DOTCHR$LLCOR$HORIZ$LRCOR$DOTCHR$TRIGHT$HORIZ$HORIZ$HORIZ$HORIZ$TLEFT$VERT$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$VERT"
"$TRIGHT$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$VERT$VERT$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$VERT$VERT$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$TLEFT"
"$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$LLCOR$LRCOR$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$DOOR$DOOR$DOOR$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$LLCOR$LRCOR$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR"
"$TUNCHR$TUNCHR$TUNCHR$TUNCHR$TUNCHR$TUNCHR$TUNCHR$SPACE$SPACE$DOTCHR$SPACE$DOTCHR$VERT$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$VERT$DOTCHR$SPACE$DOTCHR$SPACE$SPACE$TUNCHR$TUNCHR$TUNCHR$TUNCHR$TUNCHR$TUNCHR$TUNCHR"
"$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$ULCOR$URCOR$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$ULCOR$URCOR$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$URCOR"
"$VERT$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$VERT$DOTCHR$VERT$VERT$DOTCHR$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$DOTCHR$VERT$VERT$DOTCHR$VERT$SPACE$SPACE$SPACE$SPACE$SPACE$SPACE$VERT"
"$TRIGHT$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$LLCOR$LRCOR$DOTCHR$TRIGHT$HORIZ$HORIZ$HORIZ$HORIZ$TDOWN$HORIZ$TDOWN$HORIZ$HORIZ$HORIZ$HORIZ$TLEFT$DOTCHR$LLCOR$LRCOR$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$TLEFT"
"$VERT$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$VERT$SPACE$VERT$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$VERT"
"$VERT$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$VERT$SPACE$VERT$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$VERT"
"$VERT$DOTCHR$LLCOR$HORIZ$HORIZ$URCOR$SPACE$VERT$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$LLCOR$HORIZ$LRCOR$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$VERT$SPACE$ULCOR$HORIZ$HORIZ$LRCOR$DOTCHR$VERT"
"$VERT$EGZCHR$SPACE$DOTCHR$SPACE$VERT$SPACE$VERT$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$SPACE$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$VERT$SPACE$VERT$SPACE$DOTCHR$SPACE$EGZCHR$VERT"
"$TRIGHT$HORIZ$HORIZ$TLEFT$DOTCHR$LLCOR$HORIZ$LRCOR$DOTCHR$ULCOR$URCOR$DOTCHR$TRIGHT$HORIZ$HORIZ$HORIZ$HORIZ$TDOWN$HORIZ$TDOWN$HORIZ$HORIZ$HORIZ$HORIZ$TLEFT$DOTCHR$ULCOR$URCOR$DOTCHR$LLCOR$HORIZ$LRCOR$DOTCHR$TRIGHT$HORIZ$HORIZ$TLEFT"
"$VERT$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$VERT$VERT$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$VERT$SPACE$VERT$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$VERT$VERT$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$VERT"
"$VERT$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$VERT$SPACE$VERT$DOTCHR$ULCOR$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$URCOR$DOTCHR$VERT"
"$VERT$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$LLCOR$HORIZ$LRCOR$DOTCHR$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR$DOTCHR$VERT"
"$VERT$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$SPACE$DOTCHR$VERT"
"$LLCOR$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$HORIZ$LRCOR"
)

# from https://blog.dhampir.no/content/sleeping-without-a-subprocess-in-bash-and-how-to-sleep-forever
snore() {
    local IFS
    [[ -n "${_snore_fd:-}" ]] || { exec {_snore_fd}<> <(:); } 2>/dev/null ||
    {
        # workaround for MacOS and similar systems
        local fifo
        fifo=$(mktemp -u)
        mkfifo -m 700 "$fifo"
        exec {_snore_fd}<>"$fifo"
        rm "$fifo"
    }
    read ${1:+-t "$1"} -u $_snore_fd || :
}

# screen_buffer is variable, that accumulates all screen changes
# this variable is printed in controller once per game cycle
screen_buffer=''
puts() {
    screen_buffer+=${1}
}

flush_screen() {
    echo -ne "$screen_buffer"
    screen_buffer=""
}

# move cursor to (x,y) and print string
# (0,0) is upper left corner of the screen
xyprint() {
    puts "\e[$(($2 + 1));$(($1 + 1))H${3}"
}

hide_cursor() {
    echo -ne "\e[?25l"
}

show_cursor() {
    echo -ne "\e[?25h"
}

draw_maze() {
    clear
    for x in "${maze[@]}"; do
        echo -e "${PREFIX}${x}${SUFFIX}"
    done
}

get_board_at_xy() {
    echo -n "${maze[$2]:$1:1}"
}

is_wall_at_xy() {
    local -i x=$1 y=$2
    local chr
    ((x < 0)) && ((x = CMAR - 1))
    ((x > CMAR - 1)) && ((x = 0))
    ((y < 0)) && ((y = RMAR - 1))
    ((y > RMAR - 1)) && ((y = 0))
    chr="$(get_board_at_xy $x $y)"
    case "$chr" in
        $SPACE|$DOTCHR|$TUNCHR|$EGZCHR) return 1 ;;
    esac
    return 0
}

init_mstate() {
    local -i c r tmp i=-1
    local chr
#
#	this subroutine initializes the mstate table by examining the
#	pacman maze (board).  the mstate table has the same indices
#	as the maze, with the following bit assignments for each byte
#	in mstate:
#		bit 1   - set if legal to move up
#		bit 2   - set if legal to move down
#		bit 4   - set if legal to move left
#		bit 10  - set if legal to move right
#		bit 20  - set if dot present
#		bit 40  - set if energizer present
#		bit 100 - set if tunnel location
#		bit 200 - set if decision location
#
    dotcnt=0
#
#	loop through each column and row of maze
#
    for ((r = 0; r < RMAR; r++)) {
        for ((c = 0; c < CMAR; c++)) {
            ((i++))
            chr="$(get_board_at_xy $c $r)"
            ((mstate[i] = 0))
            case "$chr" in
                $DOTCHR) # this is a dot position
                    ((mstate[i] = DOT)) # set the dot bit
	            ((dotcnt++)) # increment dot count
                    ;;
                $EGZCHR) # this is an energizer position
	            ((mstate[i] = EGZ)) # set the energizer bit
	            ((dotcnt++)) # increment dot count
                    ;;
                $SPACE)
                    ((mstate[i] = 0))
                    ;;
                $TUNCHR) # this is a tunnel location
	            ((mstate[i] = TUNNEL)) # set tunnel bit, and set
                    ;;
                *) continue ;;
            esac
	    #
	    # check the adjacent locations in maze and
	    # set the directional bits accordingly
	    #
	    tmp=0
            is_wall_at_xy $c $((r + 1)) || ((mstate[i] |= DOWN, tmp++))
            is_wall_at_xy $c $((r - 1)) || ((mstate[i] |= UP, tmp++))
            is_wall_at_xy $((c + 1)) $r || ((mstate[i] |= RIGHT, tmp++))
            is_wall_at_xy $((c - 1)) $r || ((mstate[i] |= LEFT, tmp++))
            #
	    # if more than two direction bits are set,
	    # this is a 'decision' point.
	    #
	    ((tmp > 2)) && ((mstate[i] |= DECISN))
        }
    }
}

update_pacmen() {
    local -i i
    local str=""
    xyprint 70 10 "        "
    for ((i = 0; i < paccnt; i++)) {
        str+="$PMAN "
    }
    xyprint 70 10 "$str"
}

update_score() {
    ((score += $1))
    ((score >= 10000 && extra == 0)) && { # test for extra pacman
	((paccnt++)) # at 10000 points
	extra=1
        update_pacmen
    }
    xyprint 70 5 $score
}

redraw_location() {
    local -i x=$1 y=$2
    local chr="$SPACE"
    ((mstate[x + y * CMAR] & DOT)) && chr="$DOTCHR"
    ((mstate[x + y * CMAR] & EGZ)) && chr="$EGZCHR"
    ((mstate[x + y * CMAR] & TUNNEL)) && chr="$TUNCHR"
    ((fruit == 1 && x == FRUCOL && y == FRUROW)) && chr=${FRUCHR[$board]}
    xyprint $x $y "${PREFIX}${chr}${SUFFIX}"
}

restart_board() {
#
#	this routine performs the actions required either for a new board,
#	or for when pacman has been eaten.
#
    local -i i=0

    curdir=HALT	# no current motion
    newdir=HALT	# no new motion
    flush_screen
    snore 2 # admire old board for 2 seconds
    if ((state != EATEN)); then # if new board...
        init_mstate # reinitialize mstate table
	draw_maze # redraw maze
        ((board < 5)) && ((board++)) # increment board count (maximum of six boards)
        snore_time=$(printf ".%04d" $((XCYCLE[board] * 10000 / 60)))
	((cyctim = XCYCLE[board])) # reset cycle time
	((pritim = cyctim * 30)) # reset in prison time
	((frutim = cyctim * 250)) # delay time for fruit
	((frulth = cyctim * 70)) # time fruit stays displayed
	frubrd=0 # clear 'fruit this board' cnt
	((goodtm = cyctim * BGOOD[board])) # good state time
	((blnktm = cyctim * BBLNK[board])) # blink state time
        update_pacmen # show total pacmen available
        update_score 0
	for i in ${!frutbl[@]}; do # redisplay captured fruit
            xyprint ${FRUDSC[$i]} ${FRUDSR[$i]} ${frutbl[$i]}
	done
    else # else if just eaten...
        xyprint $col $row "$SPACE"
	#
	# restore character where each monster was (dot,energizer, or space)
	#
	redraw_location $lcol $lrow # lefty
	redraw_location $ccol $crow # curly
	redraw_location $fcol $frow # fluffy
	redraw_location $ncol $nrow # nellie
    fi
    state=BAD # reset system state
    eatcnt=0 # reset monsters eaten count
    timer=0 # reset system timer
    fruit=0 # clear any fruit displayed
    xyprint $FRUCOL $FRUROW "$SPACE"
    ((fruon = timer + frutim))
    ((ltim = (cyctim * 10) - pritim)) # reset monster prison times
    ((ctim = (cyctim * 20) - pritim))
    ((ftim = (cyctim * 30) - pritim))
    ((ntim = (cyctim * 40) - pritim))
    lprisn=1 # reset monsters in prison
    cprisn=1
    fprisn=1
    nprisn=1
    row=INIROW
    col=INICOL
    xyprint $col $row $PMAN # place pacman at initial loc
    lrow=LPRISR
    lcol=LPRISC
    ldir=HALT
    xyprint $lcol $lrow ${LMAN[$state]} # do the same for monsters
    crow=CPRISR
    ccol=CPRISC
    cdir=HALT
    xyprint $ccol $crow ${CMAN[$state]}
    frow=FPRISR
    fcol=FPRISC
    fdir=HALT
    xyprint $fcol $frow ${FMAN[$state]}
    nrow=NPRISR
    ncol=NPRISC
    ndir=HALT
    xyprint $ncol $nrow ${NMAN[$state]}
}

colide() {
#
#	this subroutine is called to determine if pacman has collided with
#	a monster, and if so, whether he has eaten it or vice-versa.
#	appropriate action is taken depending on who has eaten whom.
#
#	if state is bad (pacman is eaten) and a collision has occurred,
#	perform logic for pacman eaten by monster
#
    if ((state == BAD)); then
        (( (col == lcol && row == lrow) || (col == ccol && row == crow) || (col == fcol && row == frow) || (col == ncol && row == nrow) )) && {
            xyprint $col $row "${PREFIX}${TOMBST}${SUFFIX}"
            flush_screen
	    snore 2 # contemplate defeat for 2 sec.
	    state=EATEN # set state to 'eaten'
            ((paccnt--)) # decrement pacman count
            ((paccnt <= 0)) && exit # if no pacmen left, game is over
            update_pacmen
	    xyprint $col $row "$SPACE" # else rewrite a space
        }
#
#	if the state is not bad (pacman is eating) and a collision has
#	occurred, increment the score, send the monster to prison,
#	display the eating symbol, and wait one second for contemplation
#
    else
        (( col == lcol && row == lrow )) && {
            update_score $((EATSCO[eatcnt]))
            xyprint $col $row ${EATCHR[$eatcnt]}
            flush_screen
            ((++eatcnt > 3)) && {
	      state=BAD
	      eatcnt=0
	    }
            snore 1
            xyprint $col $row $PMAN
	    lrow=LPRISR
	    lcol=LPRISC
	    xyprint $lcol $lrow ${LMAN[$BAD]} # move him to prison
            flush_screen
	    lprisn=1 # mark him in prison
            ((ltim = timer + pritim)) # calculate in prison time
	}
        (( col == ccol && row == crow )) && {
            update_score $((EATSCO[eatcnt]))
            xyprint $col $row ${EATCHR[$eatcnt]}
            flush_screen
            ((++eatcnt > 3)) && {
	      state=BAD
	      eatcnt=0
	    }
            snore 1
            xyprint $col $row $PMAN
            flush_screen
	    crow=CPRISR
	    ccol=CPRISC
	    xyprint $ccol $crow ${CMAN[$BAD]} # move him to prison
	    cprisn=1 # mark him in prison
            ((ctim = timer + pritim)) # calculate in prison time
	}
        (( col == fcol && row == frow )) && {
            update_score $((EATSCO[eatcnt]))
            xyprint $col $row ${EATCHR[$eatcnt]}
            flush_screen
            ((++eatcnt > 3)) && {
	      state=BAD
	      eatcnt=0
	    }
            snore 1
            xyprint $col $row $PMAN
            flush_screen
	    frow=FPRISR
	    fcol=FPRISC
	    xyprint $fcol $frow ${FMAN[$BAD]} # move him to prison
	    fprisn=1 # mark him in prison
            ((ftim = timer + pritim)) # calculate in prison time
	}
        (( col == ncol && row == nrow )) && {
            update_score $((EATSCO[eatcnt]))
            xyprint $col $row ${EATCHR[$eatcnt]}
            flush_screen
            ((++eatcnt > 3)) && {
	      state=BAD
	      eatcnt=0
	    }
            snore 1
            xyprint $col $row $PMAN
            flush_screen
	    nrow=NPRISR
	    ncol=NPRISC
	    xyprint $ncol $nrow ${NMAN[$BAD]} # move him to prison
	    nprisn=1 # mark him in prison
            ((ntim = timer + pritim)) # calculate in prison time
	}
    fi
}

pacman_move() {
    local -i olddir=curdir
    local space_chr=$SPACE
#
#	this subroutine controls the movement of the pacman
#
    ((newdir == -1)) && return # exit program
#
#	test the status of new direction, and if legal at this location
#	set current direction equal to it. if current direction is not
#	legal at this location, set current direction to 'halt'.
#
    ((mstate[col + row * CMAR] & newdir)) && curdir=newdir # newdir legal?
    ((mstate[col + row * CMAR] & curdir)) || curdir=HALT # curdir legal?
#
#	test if we ate an energizer or dot on our last move.
#	if we did, we may not be allowed to move this cycle.
#
    ((atedot == 1)) && {
        atedot=0
	((move[cycle + 5 * 24] == 0 && olddir == curdir)) && return
    }
#
#	return if no motion specified
#
    ((curdir == HALT)) && return
#
#	else perform any required motion for pacman. (check if motion
#	is allowed this cycle. it is always allowed for change of
#	direction, so that pacman cannot be caught in a corner)
#
    ((curdir != olddir || move[cycle + (curdir - 1) * 24] == 1)) && {
        ((mstate[col + row * CMAR] & TUNNEL)) && space_chr=$TUNCHR
        xyprint $col $row "$space_chr" # blank out this loc.
        ((mstate[col + row * CMAR] & DECISN)) && { # save these co-ords.
	    pacdsc=col
	    pacdsr=row
	    pacdsd=curdir
        }
        ((curdir == LEFT)) && ((col--)) # set new coordinates
        ((curdir == UP)) && ((row--))
        ((curdir == RIGHT)) && ((col++))
        ((curdir == DOWN)) && ((row++))
        ((col > CMAR - 1)) && ((col = 0))
        ((col < 0)) && ((col = CMAR - 1))
        ((row > RMAR - 1)) && ((row = 0))
        ((row < 0)) && ((row = RMAR - 1))
	xyprint $col $row $PMAN # display pacman at
#
#	  test if we did anything useful with this latest move
#
        ((mstate[col + row * CMAR] & EGZ)) && { # just ate energizer
            ((mstate[col + row * CMAR] &= (~EGZ))) # clear energizer bit
	    state=GOOD # state = munch time
	    statim=timer # time of state change
	    update_score 50 # add 50 points
            ((dotcnt--)) # decrement dot count
	    atedot=1 # just ate energizer
        }
	((mstate[col + row * CMAR] & DOT)) && { # just ate dot
            ((mstate[col + row * CMAR] &= (~DOT))) # clear dot bit
	    update_score 10 # if so, add 10 points
            ((dotcnt--)) # decrement dot count
	    atedot=1 # just ate dot
        }
	((fruit == 1 && col == FRUCOL && row == FRUROW)) && {
	    fruit=0 # just ate fruit
            ((frucnt++)) # total fruit eaten
            ((frubrd++)) # fruit this board
            ((fruon = timer + frutim)) # reset timer for fruit
	    update_score ${FRUSCO[$board]} # increment score
            ((frucnt <= 20)) && { # display eaten fruit
                frutbl[$frucnt]=${FRUCHR[$board]}
                xyprint ${FRUDSC[$frucnt]} ${FRUDSR[$frucnt]} ${FRUCHR[$board]}
            }
	}
        ((dotcnt > 0)) && colide # if dots remain, test for collision
    }
}

wall() {
    local -i walcol=$1 walrow=$2 waldir=$3 pref=() x1 x2 y1 y2 i
#
#	this subroutine decides which direction to
#	move a monster when he runs into a wall.
#
#	determine left/right and up/down preferences
#
    if ((col > walcol)); then # pacman is to our right
	x1=RIGHT
	x2=LEFT
    else # pacman is to our left
	x1=LEFT
	x2=RIGHT
    fi
    if ((row > walrow)); then # pacman is below us
	y1=DOWN
	y2=UP
    else # pacman is above us
	y1=UP
	y2=DOWN
    fi
#
#	give preference to a ninety degree turn.
#
    if ((waldir == LEFT || waldir == RIGHT)); then
	pref[0]=y1
	pref[1]=y2
	pref[2]=x1
	pref[3]=x2
    else
	pref[0]=x1
	pref[1]=x2
	pref[2]=y1
	pref[3]=y2
    fi
#
#	select the first legal direction in our preference array
#
    for i in {0..3}; do
        ((waldir = pref[i]))
	((mstate[walcol + walrow * CMAR] & waldir)) && break
    done
    echo $waldir
}

decide() {
    local -i i deccol=$1 decrow=$2 decdir=$3 oppsit=() lversr uversd hdist vdist prefxx
#
#	this subroutine decides which direction to move a monster. it is
#	called only when the monster is at a decision point, that is it
#	has more than one direction to go not counting the direction it
#	came from. it assigns an order of precedence to the four possible
#	directions of motion. the direction it came from is not a legal
#	direction on the first two boards, and can only be selected half the
#	time on the third and fourth boards. after that, it is always a
#	legal direction. once it has assigned the preferences, it chooses 
#	the first one that is legal at its current position and returns.
#
#	it assigns the order of preference as follows:
#	 it assigns (up vs. down) and (left vs. right) precedence
#	 based on which direction moves it towards pacman.
#	 in assigning precedence to (horizontal vs. vertical) it
#	 essentially tries to 'square off' the distance between itself
#	 and pacman, that is, if pacman is farther away in the vertical
#	 direction it will give precedence to (up/down), else it gives
#	 precedence to (left/right).
#
    local -i pref=(
        LEFT UP DOWN RIGHT # pref is an order of
	LEFT DOWN UP RIGHT # precedence table
	RIGHT UP DOWN LEFT
	RIGHT DOWN UP LEFT
	UP LEFT RIGHT DOWN
	DOWN LEFT RIGHT UP
	UP RIGHT LEFT DOWN
        DOWN RIGHT LEFT UP
    )
    local -i htab=(0 1 2 3) # htab and vtab are used
    local -i vtab=(4 5 6 7) # to index pref
    (( ++dcycle > 4)) && dcycle=1 # keep track of four cycles
    oppsit[LEFT]=RIGHT
    oppsit[RIGHT]=LEFT
    oppsit[UP]=DOWN
    oppsit[DOWN]=UP
#
#	calculate horizontal and vertical distances to pacman.
#	use them to determine horizontal versus vertical preferences
#	and left versus right and up versus down preferences.
#
    lversr=2 # right over left preference
    ((hdist = col - deccol))
    ((hdist < 0)) && { # pacman is to our left
        ((hdist = -hdist))
	lversr=0 # left over right precedence
    }
    uversd=1 # down over up preference
    ((vdist = row - decrow))
    ((vdist < 0)) && { # pacman is below us
        ((vdist = -vdist))
        uversd=0 # up over down preference
    }
    ((vdist = vdist * 2)) # make distances equivalent
#
#	use the above preferences to index preference table. choose the
#	first direction in pref that is legal, except ignore the direction
#	opposite to our current direction under certain circumstances.
#
    if ((vdist > hdist)); then # vertical preference...
        if ((dcycle > 1 || deccol == col || decrow == row)); then
            ((prefxx = vtab[uversd + lversr]))
        else # (except horiz. 25% of time)
            ((prefxx = htab[uversd + lversr]))
        fi
    else # horizontal preference...
        if ((dcycle > 1 || deccol == col || decrow == row)); then
            ((prefxx = htab[uversd + lversr]))
	else # (except vert. 25% of time)
            ((prefxx = vtab[uversd + lversr]))
        fi
    fi
    if ((state == BAD)); then # monsters are chasing...
	for ((i = 0; i < 4; i++)) {
            ((pref[i + prefxx * 4] == oppsit[decdir])) && {
	        ((board < 2)) && continue # prevent opposite direction on first two boards
	        ((board < 4 && dcycle > 1)) && continue # quarter of time on next two
	        ((dcycle > 1)) && continue # half time on all others next
	    }
	    ((mstate[deccol + decrow * CMAR] & pref[i + prefxx * 4])) && {
	        ((decdir = pref[i + prefxx * 4])) # this direction is legal
                break # select it and return
	    }
	}
    else # monsters are being chased...
	for ((i = 3; i > -1; i--)) { # use reverse preference
            ((pref[i + prefxx * 4] == oppsit[decdir])) && {
	        ((board < 2)) && continue # prevent opposite direction on first two boards
	        ((board < 4 && dcycle > 1)) && continue # quarter of time on next two
	        ((dcycle > 1)) && continue # half time on all others next
            }
	    ((mstate[deccol + decrow * CMAR] & pref[i + prefxx * 4])) && {
	        ((decdir = pref[i + prefxx * 4])) # this direction is legal
                break # select it and return
	    }
	}
    fi
    echo $decdir
}

curly() {
    local -i olddir=cdir
#
#	this subroutine controls the motion of curly.
#	curly moves at 83% of top speed. he follows pacman closely
#	making a decision to change direction at every opportunity,
#	and always following pacman through an intersection when pacman
#	just preceded him through it. (pacman cannot 'shake' him easily)
#
#	test if we are in prison
#
    ((cprisn == 1)) && { # if in prison...
        ((state != BAD)) && return # dont escape if pacman is eating monsters
	((ctim + pritim > timer)) && return # too early to get out
	xyprint $CPRISC $CPRISR "$SPACE" # erase us from in prison
	crow=RDOOR
	ccol=CDOOR
	xyprint $ccol $crow ${CMAN[$state]} # move him to prison door
	cprisn=0 # no longer in prison
	cdir=HALT # no motion yet
    }
#
#	if pacman is in an eating mood (state is 'good' or 'blink'),
#	all monsters move at 67% of top speed. test for this condition.
#
    ((state != BAD && move[cycle + 24 * 8] == 0)) && {
        cdir=olddir
	return
    }
#
#	if this is a tunnel location, test if motion allowed this cycle
#
    if ((mstate[ccol + crow * CMAR] & TUNNEL)); then
        ((move[cycle + 24 * 2] == 0)) && {
	    cdir=olddir
	    return
	}
#
#	else if this is last intersection pacman traversed, follow him
#
    elif ((ccol == pacdsc && crow == pacdsr)); then
        cdir=pacdsd
#
#	else if this is a decision bit, call
#	decide to determine direction to go.
#
    elif ((mstate[ccol + crow * CMAR] & DECISN)); then
        cdir=$(decide $ccol $crow $cdir)
    fi
#
#	if we have run into a wall, find a new direction
#
    ((mstate[ccol + crow * CMAR] & cdir)) || cdir=$(wall $ccol $crow $cdir)
#
#	if motion is prohibited this cycle, reset old direction and return
#
    ((move[cycle + (cdir - 1) * 24] == 0 || move[cycle + 24 * 6] == 0)) && {
        cdir=olddir
	return
    }
#
#	all ready to move
#
    redraw_location $ccol $crow
    ((cdir == LEFT)) && ((ccol--))
    ((cdir == RIGHT)) && ((ccol++))
    ((cdir == UP)) && ((crow--))
    ((cdir == DOWN)) && ((crow++))
    ((ccol > CMAR)) && ((ccol = 0))
    ((ccol < 0)) && ((ccol = CMAR - 1))
    ((crow > RMAR)) && ((crow = 0))
    ((crow < 0)) && ((crow = RMAR - 1))
    xyprint $ccol $crow ${CMAN[$state]}
    colide # test for collision
}

lefty() {
    local -i olddir=ldir
#
#	this subroutine controls the motion of lefty.  lefty moves
#	at 92% of top speed, but does not follow pacman very well.
#	on early boards, he only changes direction when he 'sees' pacman.
#
    ((lprisn == 1)) && { # if in prison...
        ((state != BAD)) && return # dont escape if pacman is eating monsters
        ((ltim + pritim > timer)) && return # too early to get out
        xyprint $LPRISC $LPRISR "$SPACE" # erase us from in prison
        lrow=RDOOR
        lcol=CDOOR
        xyprint $lcol $lrow ${LMAN[$state]} # move him to prison door
        lprisn=0 # no longer in prison
        ldir=HALT # no motion yet
    }
#
#	if pacman is in eating mood (state is 'good' or 'blink'),
#	all monsters move at 67% of top speed. test for this condition.
#
    ((state != BAD && move[cycle + 24 * 8] == 0)) && {
        ldir=olddir
        return
    }
#
#	if this is a tunnel location, test if motion allowed this cycle
#
    if ((mstate[lcol + lrow * CMAR] & TUNNEL)); then
        ((move[cycle + 24 * 2] == 0)) && {
            ldir=olddir
            return
        }
#
#	else if this is a decision bit, and the pacman is on the same row
#	or column as we are, call decide to see if we change direction.
#	(after the second board also call decide 50% of the time, and
#	after the fourth board, call decide 67% of the time).
#
    elif ((mstate[lcol + lrow * CMAR] & DECISN)); then
        if ((lrow == row || lcol == col)); then
	    ldir=$(decide $lcol $lrow $ldir)
	elif ((board > 1 && board < 4 && move[cycle + 2 * 24] == 1)); then
	    ldir=$(decide $lcol $lrow $ldir)
	elif ((board > 3 && move[cycle + 8 * 24] == 1)); then
            ldir=$(decide $lcol $lrow $ldir)
        fi
    fi
#
#	if we have run into a wall, find a new direction
#
    ((mstate[lcol + lrow * CMAR] & ldir)) || ldir=$(wall $lcol $lrow $ldir)
#
#	if motion is prohibited this cycle, reset old direction and return
#
    ((move[cycle + (ldir - 1) * 24] == 0 || move[cycle + 24 * 4] == 0)) && {
        ldir=olddir
        return
    }
#
#	all ready to move
#
    redraw_location $lcol $lrow
    ((ldir == LEFT)) && ((lcol--))
    ((ldir == RIGHT)) && ((lcol++))
    ((ldir == UP)) && ((lrow--))
    ((ldir == DOWN)) && ((lrow++))
    ((lcol > CMAR)) && ((lcol = 0))
    ((lcol < 0)) && ((lcol = CMAR - 1))
    ((lrow > RMAR)) && ((lrow = 0))
    ((lrow < 0)) && ((lrow = RMAR - 1))
    xyprint $lcol $lrow ${LMAN[$state]}
    colide # test for collision
}

fluffy() {
    local -i olddir=fdir
#
#	this subroutine controls the motion of fluffy.
#	fluffy moves at 83% of top speed, and makes direction-changing
#	decisions at decision points approximately half the time.
#
#	test if we are in prison
#
    ((fprisn == 1)) && { # if in prison...
        ((state != BAD)) && return # dont escape if pacman is eating monsters
        ((ftim + pritim > timer)) && return # too early to get out
        xyprint $FPRISC $FPRISR "$SPACE" # erase us from in prison
        frow=RDOOR
        fcol=CDOOR
        xyprint $fcol $frow ${FMAN[$state]} # move him to prison door
        fprisn=0 # no longer in prison
        fdir=HALT # no motion yet
    }
#
#	if pacman is in an eating mood (state is 'good' or 'blink'),
#	all monsters move at 67% of top speed. test for this condition.
#
    ((state != BAD && move[cycle + 24 * 8] == 0)) && {
        fdir=olddir
        return
    }
#
#	if this is a tunnel location, test if motion allowed this cycle
#
    if ((mstate[fcol + frow * CMAR] & TUNNEL)); then
        ((move[cycle + 24 * 2] == 0)) && {
            fdir=olddir
            return
        }
#
#	else if this is a decision bit, call decide to determine direction 
#	to go. (only do when on same row or column, or, on first two boards,
#	50% of the time, on next two boards, 67% of the time, and on later
#	boards, 83% of the time).
#
    elif ((mstate[fcol + frow * CMAR] & DECISN)); then
	if ((fcol == col || frow == row)); then
            fdir=$(decide $fcol $frow $fdir)
        elif ((board < 2 && move[cycle + 24 * 2] == 1)); then
            fdir=$(decide $fcol $frow $fdir)
        elif ((board > 1 && board < 4 && move[cycle + 24 * 6] == 1)); then
            fdir=$(decide $fcol $frow $fdir)
        elif ((board > 3 && move[cycle + 24 * 8] == 1)); then
            fdir=$(decide $fcol $frow $fdir)
	fi
    fi
#
#	if we have run into a wall, find a new direction
#
    ((mstate[fcol + frow * CMAR] & fdir)) || fdir=$(wall $fcol $frow $fdir)
#
#	if motion is prohibited this cycle, reset old direction and return
#
    ((move[cycle + (fdir - 1) * 24] == 0 || move[cycle + 24 * 6] == 0)) && {
        fdir=olddir
        return
    }
#
#	all ready to move
#
    redraw_location $fcol $frow
    ((fdir == LEFT)) && ((fcol--))
    ((fdir == RIGHT)) && ((fcol++))
    ((fdir == UP)) && ((frow--))
    ((fdir == DOWN)) && ((frow++))
    ((fcol > CMAR)) && ((fcol = 0))
    ((fcol < 0)) && ((fcol = CMAR - 1))
    ((frow > RMAR)) && ((frow = 0))
    ((frow < 0)) && ((frow = RMAR - 1))
    xyprint $fcol $frow ${FMAN[$state]}
    colide # test for collision
}

nellie() {
    local -i olddir=ndir
#
#	this subroutine controls the motion of nellie.
#	nellie moves at 83% of top speed, and makes direction-changing
#	decisions at decision points approximately half the time.
#
#	test if we are in prison
#
    ((nprisn == 1)) && { # if in prison...
        ((state != BAD)) && return # dont escape if pacman is eating monsters
        ((ntim + pritim > timer)) && return # too early to get out
        xyprint $NPRISC $NPRISR "$SPACE" # erase us from in prison
        nrow=RDOOR
        ncol=CDOOR
        xyprint $ncol $nrow ${NMAN[$state]} # move him to prison door
        nprisn=0 # no longer in prison
        ndir=HALT # no motion yet
    }
#
#	if pacman is in an eating mood (state is 'good' or 'blink'),
#	all monsters move at 67% of top speed. test for this condition.
#
    ((state != BAD && move[cycle + 24 * 8] == 0)) && {
        ndir=olddir
        return
    }
#
#	if this is a tunnel location, test if motion allowed this cycle
#
    if ((mstate[ncol + nrow * CMAR] & TUNNEL)); then
        ((move[cycle + 24 * 2] == 0)) && {
            ndir=olddir
            return
        }
#
#	else if this is a decision bit, call decide to determine direction
#	to go. (only do this if on same row or column, or, for first two
#	boards, 50% of the time, or for the next two boards, 75% of the
#	time, or for later boards, 92% of the time).
#
    elif ((mstate[ncol + nrow * CMAR] & DECISN)); then
	if ((ncol == col || nrow == row)); then
            ndir=$(decide $ncol $nrow $ndir)
        elif ((board < 2 && move[cycle + 24 * 2] == 0)); then
            ndir=$(decide $ncol $nrow $ndir)
        elif ((board > 1 && board < 4 && move[cycle + 24 * 5] == 1)); then
            ndir=$(decide $ncol $nrow $ndir)
        elif ((board > 3 && move[cycle + 24 * 4] == 1)); then
            ndir=$(decide $ncol $nrow $ndir)
	fi
    fi
#
#	if we have run into a wall, find a new direction
#
    ((mstate[ncol + nrow * CMAR] & ndir)) || ndir=$(wall $ncol $nrow $ndir)
#
#	if motion is prohibited this cycle, reset old direction and return
#
    ((move[cycle + (ndir - 1) * 24] == 0 || move[cycle + 24 * 6] == 0)) && {
        ndir=olddir
        return
    }
#
#	all ready to move
#
    redraw_location $ncol $nrow
    ((ndir == LEFT)) && ((ncol--))
    ((ndir == RIGHT)) && ((ncol++))
    ((ndir == UP)) && ((nrow--))
    ((ndir == DOWN)) && ((nrow++))
    ((ncol > CMAR)) && ((ncol = 0))
    ((ncol < 0)) && ((ncol = CMAR - 1))
    ((nrow > RMAR)) && ((nrow = 0))
    ((nrow < 0)) && ((nrow = RMAR - 1))
    xyprint $ncol $nrow ${NMAN[$state]}
    colide # test for collision
}

do_cycle() {
#
#	each pass through is one 'cycle'. the current
#	cycle number is incremented. (there are 24 cycles. each man is
#	only allowed motion on certain cycles, so we can simulate various
#	speeds).
#	
    cycle=$((++cycle % 24))
    pacman_move
    ((dotcnt <= 0)) && { # if out of dots
        restart_board # reset board
        return
    }
    ((state != EATEN)) && lefty # process lefty's motion
    ((state != EATEN)) && curly # process curly's motion
    ((state != EATEN)) && fluffy # process fluffy's motion
    ((state != EATEN)) && nellie # process nellie's motion
    ((state == EATEN && gamovr == 0)) && restart_board # restart if pacman eaten
    #
    # test for changes in fruit display status. (at appropriate
    # times display or undisplay fruit)
    #
    if ((fruit == 0)); then # if fruit not displayed
        ((fruon < timer && frubrd < 5)) && { # test if time to display
	    fruit=1 # (limit 5 fruit per board)
            xyprint $FRUCOL $FRUROW ${FRUCHR[$board]}
	    ((fruoff = timer + frulth))
	}
    else # if fruit displayed
        ((fruoff < timer)) && { # test if time to undisplay
	    fruit=0
            ((frubrd++))
            xyprint $FRUCOL $FRUROW "$SPACE"
	    ((fruon = timer + frutim))
        }
    fi
    #
    # test for state changes
    #
    if ((state == GOOD)); then # if state is 'good',
        ((statim + goodtm <= timer)) && { # and timer has run out,
	      state=BLINK # set state to 'blink'
	      statim=timer
	}
    elif ((state == BLINK)); then # else if state is 'blink',
        ((statim + blnktm <= timer)) && { # and timer has run out,
	      state=BAD # set state to 'bad'.
	      eatcnt=0 # clear monsters eaten count
              xyprint $lcol $lrow ${LMAN[$BAD]} # redisplay monsters
              xyprint $ccol $crow ${CMAN[$BAD]}
              xyprint $fcol $frow ${FMAN[$BAD]}
              xyprint $ncol $nrow ${NMAN[$BAD]}
	}
    fi
    ((timer = timer + cyctim)) # increment elapsed cycle time
}

intro() {
    local i delay=0.05
    clear
    xyprint 35 8 "${LMAN[$BAD]} - LEFTY"
    xyprint 35 10 "${CMAN[$BAD]} - CURLY"
    xyprint 35 12 "${FMAN[$BAD]} - FLUFFY"
    xyprint 35 14 "${NMAN[$BAD]} - NELLIE"
    flush_screen
    snore 2
    for ((i = 9; i < 60; i++)) {
        xyprint $i 21 " ${NMAN[$BAD]}  ${FMAN[$BAD]}  ${CMAN[$BAD]}  ${LMAN[$BAD]}      $PMAN"
        flush_screen
        snore $delay
    }
}

stty_g=$(stty -g) # let's save terminal state
hide_cursor
stty -echo
#intro

at_exit() {
    xyprint $GAMEOVER_X $GAMEOVER_Y "Game over!"
    flush_screen
    show_cursor
    stty $stty_g # let's restore terminal state
    echo
}

main() {
    local esc_ch=$'\x1b' a='' b='' key
    local -A dirmap=([A]=$UP [B]=$DOWN [C]=$RIGHT [D]=$LEFT)
    trap at_exit EXIT
    restart_board
    while true; do
        while read -t 0.001 -s -n1 key ; do
            case "$a$b$key" in
                "${esc_ch}["[ABCD]) newdir=${dirmap[$key]} ;;
                *${esc_ch}${esc_ch}) exit ;;            # exit on 2 escapes
                *[qQ]) exit ;;               # regular key. If space was pressed $key is empty
            esac
            a=$b   # preserve previous keys
            b=$key
        done
        flush_screen
        do_cycle
        snore $snore_time
    done
}

main
