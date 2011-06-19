/*
 * Timer Constants
 */
/**
 * Timer period occupying 1ms of time.
 */
#define TIMER_PERIOD	Fcy / 1000

#if (TIMER_PERIOD > 65535)
	#error "Timer period outside timer range"
#endif

/*
 * Function Prototypes
 */
void Timer_Init();
void Timer_UpdateClock();

void Timer_Delay (unsigned int delay);

void Timer_Start();
void Timer_Stop();
unsigned char Timer_GetTriggered();
