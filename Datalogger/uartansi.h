/**
 * ESC character.
 */
#define	ANSI_ESC			0x1B
/**
 * Single-character Control Sequence Introducer (CSI).
 */
#define ANSI_CSI			0x9B

/**
 * Whether to use the single-character CSI or not.
 */
#define ANSI_USE_SINGLE_CSI

void ANSI_PutCSI();
void ANSI_Command( char cmd );
void ANSI_Command1( char arg, char cmd );
void ANSI_Command1s( char* arg, char cmd );

/**
 * ANSI special character sequence codes.
 */
#define	ANSI_SEQ_CUU		'A'		// Cursor Up
#define ANSI_SEQ_CUD		'B'		// Cursor Down
#define ANSI_SEQ_CUF		'C'		// Cursor Forward
#define ANSI_SEQ_CUB		'D'		// Cursor Back
#define ANSI_SEQ_CNL		'E'		// Cursor Next Line
#define ANSI_SEQ_CPL		'F'		// Cursor Previous Line
#define ANSI_SEQ_CHA		'G'		// Cursor Horizontal Absolute
#define ANSI_SEQ_CUP		'H'		// Cursor Position
#define ANSI_SEQ_ED			'J'		// Erase Data
#define ANSI_SEQ_EL			'K'		// Erase in Line
#define ANSI_SEQ_SU			'S'		// Scroll Up
#define ANSI_SEQ_SD			'T'		// Scroll Down
#define ANSI_SEQ_HVP		'f'		// Horizontal and Vertical Position (same as CUP)
#define ANSI_SEQ_SGR		'm'		// Select Graphic Rendition

#define ANSI_SEQ_SCP		's'		// Save Cursor Position
#define ANSI_SEQ_RCP		'u'		// Restore Cursor Position

#define ANSI_SGR_RESET		'0'
#define ANSI_SGR_BRIGHT		'1'
#define ANSI_SGR_FAINT		'2'
#define ANSI_SGR_ITALIC		'3'
#define ANSI_SGR_UNDERLINE	'4'
#define ANSI_SGR_BLINK_SLOW	'5'
#define ANSI_SGR_BLINK_FAST	'6'
#define ANSI_SGR_NEGATIVE	'7'


void ANSI_SetColor( char colorCode );

/**
 * ANSI Color codes.
 */
#define	ANSI_COLOR_BLACK	'0'
#define	ANSI_COLOR_RED		'1'
#define	ANSI_COLOR_GREEN	'2'
#define	ANSI_COLOR_YELLOW	'3'
#define	ANSI_COLOR_BLUE		'4'
#define	ANSI_COLOR_MAGENTA	'5'
#define	ANSI_COLOR_CYAN		'6'
#define	ANSI_COLOR_WHITE	'7'
