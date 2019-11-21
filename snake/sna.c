/*
 *  The Snake game.
 *
 *  Compile it with gcc -o sna sna.c -lcurses
 *
 *  Use left and right arrows to control snake, q to quit.
 *  The goal of the game is to grow as big snake as you can.
 *  Snake grows when it eats rabbits (denoted by numbers 1..9).
 *  Number defines how much snake would grow after eating certain rabbit.
 *  Sometime mongoose would appear on the field denoted by M symbols.
 *  Game would end if you hit mongoose, border or snake itself.
 *  Enjoy :)!
 *
 *  Copyright 2013 Kirill Timofeev kt97679@gmail.com
 *  The program is released under the GNU General Public License version 2.
 *  There is NO WARRANTY.
 */

#include <curses.h>
#include <string.h>
#include <stdlib.h>

#define MAXROW 24 // size of play field
#define MAXCOL 79 // resembling old terminals

#define SCORE_OFFSET 10     // constants that define positions to output score ...
#define RABBITS_OFFSET 9    // ... number of rabbits eaten and ...
#define GAME_OVER_OFFSET 22 // ... final "game over" message

#define SNACHR '0'          // snake is drawn using '0' symbol
#define MNGCHR 'M'          // mongooses are drawn using 'M' symbol
#define SPACE  ' '          // space is used to clear play field cell
#define RABBIT_BASE_CHR '0' // rabbits are numbers 1..9, are displayed by adding rabbit value to base rabbit char

#define INITIAL_ROW 12      // snake start row
#define INITIAL_COL 35      // snake start column
#define INITIAL_LENGTH 10   // snake start length
#define INITIAL_DIR 0       // snake movement direction at the begining

#define DELAY 100000        // delay to make game not too fast
#define NUM_OF_DIRECTIONS 4 // 4 directions are possible: 0 - right, 1 - down, 2 - left, 3 - up
#define OBSTACLE_VALUE 15   // value of cell with obstacle (play field border or mongoose)
#define DIRECTION_BASE_VALUE 10 // direction to next cell of the snake is saved to current cell being added to this base value
#define RABBIT_MAX_VALUE 9  // rabbit can't be more than 9

#define ADD_OBJECT_CHANCE 32 // inverted probability that this cycle object would be added to play field
#define ADD_RABBIT_CHANCE 4  // inverted probability that added object would be mongoose

char data[(MAXROW + 1) * (MAXCOL + 1)] = {}; // play field data storage

// data storage is a one dimensional array of chars
// index in array is calculated as row * MAXCOL + col
// value in each array element can be:
// 0 - empty play field cell
// 1..9 - rabbit
// 10..13 - snake body, direction to next cell with snake body
// 15 - obstacle (mongoose or playfield border)
// theoretically it is possible to use only 4 bits for single play field cell

main() {
    int press_key_to_exit = 0; // flag to pause before exit since game screen would go away
    int score = INITIAL_LENGTH;
    int rabbits = 0;
    int dir = INITIAL_DIR; // head direction
    int food = 0;          // how many rabbit units were eaten by snake
    int head[] = {INITIAL_ROW, INITIAL_COL}; // 2 element array (element 0 - row, element 1 - column) pointer to the head of the snake ...
    int tail[] = {INITIAL_ROW, INITIAL_COL}; // ... and tail

    initscr();              // First
    leaveok(stdscr, FALSE); // we
    cbreak();               // need
    noecho();               // to
    nodelay(stdscr, TRUE);  // initialize
    keypad(stdscr, TRUE);   // curses
    curs_set(0);            // stuff
    init_game(head);        // after that we can init random number generator, draw border around play field and draw initial snake
    update_score(score, rabbits);                           // init of score and rabbits eaten screen values
    while ((dir = getdir(dir)) != -1) {                     // main loop. Continue until getdir() returns -1 (q was pressed)
        set_cell(head, DIRECTION_BASE_VALUE + dir, SNACHR); // since we got new head direction we can set direction for current head location
        update_pointer(head, dir);                          // head pointer is changed according to current direction
        int new_head_value = get_cell(head);                // let's see what is in the new head cell location
        if (new_head_value > RABBIT_MAX_VALUE) {            // all values over max rabbit values are obstacles
            press_key_to_exit = 1;                          // if obstacle is hit let's set flag to pause before exit
            break;                                          // and stop the main loop
        }
        if (food == 0) {                                          // if all rabbit units are consumed
            int tail_dir = get_cell(tail) - DIRECTION_BASE_VALUE; // let's remember current tail direction
            set_cell(tail, 0, SPACE);                             // clear play field cell where tail is located
            update_pointer(tail, tail_dir);                       // and move tail to next position
        } else {
            food--;                                               // if not all rabbit units were consumed tail is not updated, remaining rabbit units are decremented
            update_score(++score, rabbits);                       // and score is updated
        }
        set_cell(head, DIRECTION_BASE_VALUE + dir, SNACHR);       // let's draw SNACHR in new head location and mark this cell as occupied using current direction
        if (new_head_value > 0) {                                 // if new head location contains rabbit let's eat it
            update_score(score, ++rabbits);                       // update number of rabbits eaten
            food += new_head_value;                               // and add rabbit value to unconsumed rabbit units
        }
        add_object(); // let's add new rabbit or mongoose to play field
        refresh();    // in order to see changes on the screen we need to call refresh()
        pause(dir);   // and pause game so that it would not be too fast
    }                 // end of main loop
    end_game();       // let's print final "game over" message
    if (press_key_to_exit) {    // this flag is set only if snake hits obstacle, not if user requested exit
        nodelay(stdscr, FALSE); // getch() would wait for keypress
        getch();
    }
    endwin(); // finalize curses session
    exit(0);  // and exit
}

end_game() { // function to print final "game over" message
    move(MAXROW, GAME_OVER_OFFSET);
    addstr(" Game over, press any key to exit ");
    refresh();
}

update_pointer(int *pointer, int dir) { // function to update play field pointer according to direction
    int hshift[] = {1, 0, -1, 0};       // array with horizontal shift values for each direction
    int vshift[] = {0, 1, 0, -1};       // array with vertical shift values for each direction
    pointer[0] += vshift[dir];          // element 0 contains row value
    pointer[1] += hshift[dir];          // element 1 contains column value
}

init_game(int *head) { // init of random number generator, drawing of play field border and initial snake
    int i;
    srandom(time(NULL)); // random number generator is initialized with current time value
    for(i = 0; i < INITIAL_LENGTH; i++) { // let's draw initial snake
        if (i > 0) {                      // don't update head pointer if this is snake's tail
            update_pointer(head, INITIAL_DIR);
        }
        set_cell(head, DIRECTION_BASE_VALUE + INITIAL_DIR, SNACHR); // put appropriate direction value into play field cell and display SNACHR
    }
    int ptr[] = {0, 0}; // pointer for drawing play field border
    int dir;            // border drawing direction
    int length[] = {MAXCOL, MAXROW, MAXCOL, MAXROW};                         // number of cells for border for each direction
    int sym[] = {ACS_HLINE, ACS_VLINE, ACS_HLINE, ACS_VLINE};                // symbol to be used to draw border for each direction
    int corner[] = {ACS_ULCORNER, ACS_URCORNER, ACS_LRCORNER, ACS_LLCORNER}; // corner symbols for each direction
    for (dir = 0; dir < NUM_OF_DIRECTIONS; dir++) {                          // let's cycle through all directions
        for (i = 0; i < length[dir]; i++) {                                  // and go through the whole border side
            set_cell(ptr, OBSTACLE_VALUE, i == 0 ? corner[dir] : sym[dir]);  // 1st position is corner, cell value is always obstacle
            update_pointer(ptr, dir);
        }
    }
}

pause(int dir) {                 // play field cell ratio is approximately 2 so we need to vary game delay depending where snake goes
    int factor[] = {1, 2, 1, 2}; // delay factor for each direction
    usleep(factor[dir] * DELAY); // now let's wait
}

int getdir(int dir) { // function to update direction of snake movement according to keys pressed
    switch(getch()) {
        case KEY_LEFT: return (dir + (NUM_OF_DIRECTIONS - 1)) % NUM_OF_DIRECTIONS;
        case KEY_RIGHT: return (dir + 1) % NUM_OF_DIRECTIONS;
        case 'q' :
        case 'Q' : return -1;
        default: return dir;
    }
}

add_object() { // this function adds rabbits and mongooses to play field
    int ptr[] = {0, 0};

    if ((random() % ADD_OBJECT_CHANCE) != 0) { // object is added with probability 1/ADD_OBJECT_CHANCE
        return;
    }
    while(get_cell(ptr) != 0) {     // let's find empty cell
        ptr[0] = random() % MAXROW; // row
        ptr[1] = random() % MAXCOL; // column
    }
    if ((random() % ADD_RABBIT_CHANCE) != 0) {           // mongoose is added with probability 1/ADD_RABBIT_CHANCE
        int rabbit = 1 + random() % RABBIT_MAX_VALUE;    // rabbit has value in the 1..RABBIT_MAX_VALUE range
        set_cell(ptr, rabbit, rabbit + RABBIT_BASE_CHR); // let's add rabbit value to play field cell and appropriate symbol to the screen
    } else {
        set_cell(ptr, OBSTACLE_VALUE, MNGCHR);           // mongoose is added
    }
}

update_score(int score, int rabbits) { // function to update score and number of rabbits on the screen
    char buf[32];
    move(0, SCORE_OFFSET);
    sprintf(buf, " Length : %d ", score);
    addstr(buf);
    sprintf(buf, " Rabbits : %d \0", rabbits);
    move(0, MAXCOL - strlen(buf) - RABBITS_OFFSET);
    addstr(buf);
}

set_cell(int *ptr, int value, int sym) { // function to set play field cell and output appropriate symbol to the screen
    move(ptr[0], ptr[1]);                             // move cursor to certain screen location
    addch(sym);                                       // output symbol
    *(data + ptr[0] * MAXCOL + ptr[1]) = (char)value; // update cell value
}

int get_cell(int *ptr) { // function to retrieve field cell value
    return *(data + ptr[0] * MAXCOL + ptr[1]);
}

