#
# Generated Makefile - do not edit!
#
# Edit the Makefile in the project folder instead (../Makefile). Each target
# has a -pre and a -post target defined where you can add customized code.
#
# This makefile implements configuration specific macros and targets.


# Include project Makefile
include Makefile

# Environment
MKDIR=mkdir -p
RM=rm -f 
CP=cp 
# Macros
CND_CONF=default

ifeq ($(TYPE_IMAGE), DEBUG_RUN)
IMAGE_TYPE=debug
FINAL_IMAGE=dist/${CND_CONF}/${IMAGE_TYPE}/calsol-datalogger-pic24h.X.${IMAGE_TYPE}.elf
else
IMAGE_TYPE=production
FINAL_IMAGE=dist/${CND_CONF}/${IMAGE_TYPE}/calsol-datalogger-pic24h.X.${IMAGE_TYPE}.elf
endif
# Object Directory
OBJECTDIR=build/${CND_CONF}/${IMAGE_TYPE}
# Distribution Directory
DISTDIR=dist/${CND_CONF}/${IMAGE_TYPE}

# Object Files
OBJECTFILES=${OBJECTDIR}/sd-spi-dma.o ${OBJECTDIR}/ecan.o ${OBJECTDIR}/sd-spi.o ${OBJECTDIR}/i2c-phy.o ${OBJECTDIR}/timer.o ${OBJECTDIR}/uart.o ${OBJECTDIR}/fat32.o ${OBJECTDIR}/fat32-file.o ${OBJECTDIR}/main.o ${OBJECTDIR}/sd-spi-debug.o ${OBJECTDIR}/uart-dma.o ${OBJECTDIR}/fat32-file-opt.o ${OBJECTDIR}/debug-common.o ${OBJECTDIR}/sd-spi-cmd.o ${OBJECTDIR}/uartansi.o ${OBJECTDIR}/uartstring.o ${OBJECTDIR}/mcp23017.o ${OBJECTDIR}/sd-spi-phy.o


CFLAGS=
ASFLAGS=
LDLIBSOPTIONS=

# Path to java used to run MPLAB X when this makefile was created
MP_JAVA_PATH=C:\\Program\ Files\ \(x86\)\\Java\\jre6/bin/
OS_ORIGINAL="MINGW32_NT-6.1"
OS_CURRENT="$(shell uname -s)"
############# Tool locations ##########################################
# If you copy a project from one host to another, the path where the  #
# compiler is installed may be different.                             #
# If you open this project with MPLAB X in the new host, this         #
# makefile will be regenerated and the paths will be corrected.       #
#######################################################################
MP_CC=C:\\Program\ Files\ \(x86\)\\Microchip\\mplabc30\\v3.25\\bin\\pic30-gcc.exe
# MP_BC is not defined
MP_AS=C:\\Program\ Files\ \(x86\)\\Microchip\\mplabc30\\v3.25\\bin\\pic30-as.exe
MP_LD=C:\\Program\ Files\ \(x86\)\\Microchip\\mplabc30\\v3.25\\bin\\pic30-ld.exe
MP_AR=C:\\Program\ Files\ \(x86\)\\Microchip\\mplabc30\\v3.25\\bin\\pic30-ar.exe
# MP_BC is not defined
MP_CC_DIR=C:\\Program\ Files\ \(x86\)\\Microchip\\mplabc30\\v3.25\\bin
# MP_BC_DIR is not defined
MP_AS_DIR=C:\\Program\ Files\ \(x86\)\\Microchip\\mplabc30\\v3.25\\bin
MP_LD_DIR=C:\\Program\ Files\ \(x86\)\\Microchip\\mplabc30\\v3.25\\bin
MP_AR_DIR=C:\\Program\ Files\ \(x86\)\\Microchip\\mplabc30\\v3.25\\bin
# MP_BC_DIR is not defined
.build-conf: ${BUILD_SUBPROJECTS}
ifneq ($(OS_CURRENT),$(OS_ORIGINAL))
	@echo "***** WARNING: This make file contains OS dependent code. The OS this makefile is being run is different from the OS it was created in."
endif
	${MAKE}  -f nbproject/Makefile-default.mk dist/${CND_CONF}/${IMAGE_TYPE}/calsol-datalogger-pic24h.X.${IMAGE_TYPE}.elf

MP_PROCESSOR_OPTION=33FJ128MC802
MP_LINKER_FILE_OPTION=,-Tp33FJ128MC802.gld
# ------------------------------------------------------------------------------------
# Rules for buildStep: assemble
ifeq ($(TYPE_IMAGE), DEBUG_RUN)
else
endif

# ------------------------------------------------------------------------------------
# Rules for buildStep: compile
ifeq ($(TYPE_IMAGE), DEBUG_RUN)
${OBJECTDIR}/sd-spi-dma.o: sd-spi-dma.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/sd-spi-dma.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/sd-spi-dma.o.d -o ${OBJECTDIR}/sd-spi-dma.o sd-spi-dma.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/sd-spi-dma.o.d > ${OBJECTDIR}/sd-spi-dma.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-dma.o.d 
	${CP} ${OBJECTDIR}/sd-spi-dma.o.tmp ${OBJECTDIR}/sd-spi-dma.o.d 
	${RM} ${OBJECTDIR}/sd-spi-dma.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/sd-spi-dma.o.d > ${OBJECTDIR}/sd-spi-dma.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-dma.o.d 
	${CP} ${OBJECTDIR}/sd-spi-dma.o.tmp ${OBJECTDIR}/sd-spi-dma.o.d 
	${RM} ${OBJECTDIR}/sd-spi-dma.o.tmp
endif
${OBJECTDIR}/ecan.o: ecan.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/ecan.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/ecan.o.d -o ${OBJECTDIR}/ecan.o ecan.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/ecan.o.d > ${OBJECTDIR}/ecan.o.tmp
	${RM} ${OBJECTDIR}/ecan.o.d 
	${CP} ${OBJECTDIR}/ecan.o.tmp ${OBJECTDIR}/ecan.o.d 
	${RM} ${OBJECTDIR}/ecan.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/ecan.o.d > ${OBJECTDIR}/ecan.o.tmp
	${RM} ${OBJECTDIR}/ecan.o.d 
	${CP} ${OBJECTDIR}/ecan.o.tmp ${OBJECTDIR}/ecan.o.d 
	${RM} ${OBJECTDIR}/ecan.o.tmp
endif
${OBJECTDIR}/sd-spi.o: sd-spi.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/sd-spi.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/sd-spi.o.d -o ${OBJECTDIR}/sd-spi.o sd-spi.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/sd-spi.o.d > ${OBJECTDIR}/sd-spi.o.tmp
	${RM} ${OBJECTDIR}/sd-spi.o.d 
	${CP} ${OBJECTDIR}/sd-spi.o.tmp ${OBJECTDIR}/sd-spi.o.d 
	${RM} ${OBJECTDIR}/sd-spi.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/sd-spi.o.d > ${OBJECTDIR}/sd-spi.o.tmp
	${RM} ${OBJECTDIR}/sd-spi.o.d 
	${CP} ${OBJECTDIR}/sd-spi.o.tmp ${OBJECTDIR}/sd-spi.o.d 
	${RM} ${OBJECTDIR}/sd-spi.o.tmp
endif
${OBJECTDIR}/i2c-phy.o: i2c-phy.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/i2c-phy.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/i2c-phy.o.d -o ${OBJECTDIR}/i2c-phy.o i2c-phy.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/i2c-phy.o.d > ${OBJECTDIR}/i2c-phy.o.tmp
	${RM} ${OBJECTDIR}/i2c-phy.o.d 
	${CP} ${OBJECTDIR}/i2c-phy.o.tmp ${OBJECTDIR}/i2c-phy.o.d 
	${RM} ${OBJECTDIR}/i2c-phy.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/i2c-phy.o.d > ${OBJECTDIR}/i2c-phy.o.tmp
	${RM} ${OBJECTDIR}/i2c-phy.o.d 
	${CP} ${OBJECTDIR}/i2c-phy.o.tmp ${OBJECTDIR}/i2c-phy.o.d 
	${RM} ${OBJECTDIR}/i2c-phy.o.tmp
endif
${OBJECTDIR}/timer.o: timer.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/timer.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/timer.o.d -o ${OBJECTDIR}/timer.o timer.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/timer.o.d > ${OBJECTDIR}/timer.o.tmp
	${RM} ${OBJECTDIR}/timer.o.d 
	${CP} ${OBJECTDIR}/timer.o.tmp ${OBJECTDIR}/timer.o.d 
	${RM} ${OBJECTDIR}/timer.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/timer.o.d > ${OBJECTDIR}/timer.o.tmp
	${RM} ${OBJECTDIR}/timer.o.d 
	${CP} ${OBJECTDIR}/timer.o.tmp ${OBJECTDIR}/timer.o.d 
	${RM} ${OBJECTDIR}/timer.o.tmp
endif
${OBJECTDIR}/uart.o: uart.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/uart.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/uart.o.d -o ${OBJECTDIR}/uart.o uart.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/uart.o.d > ${OBJECTDIR}/uart.o.tmp
	${RM} ${OBJECTDIR}/uart.o.d 
	${CP} ${OBJECTDIR}/uart.o.tmp ${OBJECTDIR}/uart.o.d 
	${RM} ${OBJECTDIR}/uart.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/uart.o.d > ${OBJECTDIR}/uart.o.tmp
	${RM} ${OBJECTDIR}/uart.o.d 
	${CP} ${OBJECTDIR}/uart.o.tmp ${OBJECTDIR}/uart.o.d 
	${RM} ${OBJECTDIR}/uart.o.tmp
endif
${OBJECTDIR}/fat32.o: fat32.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/fat32.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/fat32.o.d -o ${OBJECTDIR}/fat32.o fat32.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/fat32.o.d > ${OBJECTDIR}/fat32.o.tmp
	${RM} ${OBJECTDIR}/fat32.o.d 
	${CP} ${OBJECTDIR}/fat32.o.tmp ${OBJECTDIR}/fat32.o.d 
	${RM} ${OBJECTDIR}/fat32.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/fat32.o.d > ${OBJECTDIR}/fat32.o.tmp
	${RM} ${OBJECTDIR}/fat32.o.d 
	${CP} ${OBJECTDIR}/fat32.o.tmp ${OBJECTDIR}/fat32.o.d 
	${RM} ${OBJECTDIR}/fat32.o.tmp
endif
${OBJECTDIR}/fat32-file.o: fat32-file.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/fat32-file.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/fat32-file.o.d -o ${OBJECTDIR}/fat32-file.o fat32-file.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/fat32-file.o.d > ${OBJECTDIR}/fat32-file.o.tmp
	${RM} ${OBJECTDIR}/fat32-file.o.d 
	${CP} ${OBJECTDIR}/fat32-file.o.tmp ${OBJECTDIR}/fat32-file.o.d 
	${RM} ${OBJECTDIR}/fat32-file.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/fat32-file.o.d > ${OBJECTDIR}/fat32-file.o.tmp
	${RM} ${OBJECTDIR}/fat32-file.o.d 
	${CP} ${OBJECTDIR}/fat32-file.o.tmp ${OBJECTDIR}/fat32-file.o.d 
	${RM} ${OBJECTDIR}/fat32-file.o.tmp
endif
${OBJECTDIR}/main.o: main.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/main.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/main.o.d -o ${OBJECTDIR}/main.o main.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/main.o.d > ${OBJECTDIR}/main.o.tmp
	${RM} ${OBJECTDIR}/main.o.d 
	${CP} ${OBJECTDIR}/main.o.tmp ${OBJECTDIR}/main.o.d 
	${RM} ${OBJECTDIR}/main.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/main.o.d > ${OBJECTDIR}/main.o.tmp
	${RM} ${OBJECTDIR}/main.o.d 
	${CP} ${OBJECTDIR}/main.o.tmp ${OBJECTDIR}/main.o.d 
	${RM} ${OBJECTDIR}/main.o.tmp
endif
${OBJECTDIR}/sd-spi-debug.o: sd-spi-debug.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/sd-spi-debug.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/sd-spi-debug.o.d -o ${OBJECTDIR}/sd-spi-debug.o sd-spi-debug.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/sd-spi-debug.o.d > ${OBJECTDIR}/sd-spi-debug.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-debug.o.d 
	${CP} ${OBJECTDIR}/sd-spi-debug.o.tmp ${OBJECTDIR}/sd-spi-debug.o.d 
	${RM} ${OBJECTDIR}/sd-spi-debug.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/sd-spi-debug.o.d > ${OBJECTDIR}/sd-spi-debug.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-debug.o.d 
	${CP} ${OBJECTDIR}/sd-spi-debug.o.tmp ${OBJECTDIR}/sd-spi-debug.o.d 
	${RM} ${OBJECTDIR}/sd-spi-debug.o.tmp
endif
${OBJECTDIR}/uart-dma.o: uart-dma.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/uart-dma.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/uart-dma.o.d -o ${OBJECTDIR}/uart-dma.o uart-dma.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/uart-dma.o.d > ${OBJECTDIR}/uart-dma.o.tmp
	${RM} ${OBJECTDIR}/uart-dma.o.d 
	${CP} ${OBJECTDIR}/uart-dma.o.tmp ${OBJECTDIR}/uart-dma.o.d 
	${RM} ${OBJECTDIR}/uart-dma.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/uart-dma.o.d > ${OBJECTDIR}/uart-dma.o.tmp
	${RM} ${OBJECTDIR}/uart-dma.o.d 
	${CP} ${OBJECTDIR}/uart-dma.o.tmp ${OBJECTDIR}/uart-dma.o.d 
	${RM} ${OBJECTDIR}/uart-dma.o.tmp
endif
${OBJECTDIR}/fat32-file-opt.o: fat32-file-opt.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/fat32-file-opt.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/fat32-file-opt.o.d -o ${OBJECTDIR}/fat32-file-opt.o fat32-file-opt.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/fat32-file-opt.o.d > ${OBJECTDIR}/fat32-file-opt.o.tmp
	${RM} ${OBJECTDIR}/fat32-file-opt.o.d 
	${CP} ${OBJECTDIR}/fat32-file-opt.o.tmp ${OBJECTDIR}/fat32-file-opt.o.d 
	${RM} ${OBJECTDIR}/fat32-file-opt.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/fat32-file-opt.o.d > ${OBJECTDIR}/fat32-file-opt.o.tmp
	${RM} ${OBJECTDIR}/fat32-file-opt.o.d 
	${CP} ${OBJECTDIR}/fat32-file-opt.o.tmp ${OBJECTDIR}/fat32-file-opt.o.d 
	${RM} ${OBJECTDIR}/fat32-file-opt.o.tmp
endif
${OBJECTDIR}/debug-common.o: debug-common.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/debug-common.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/debug-common.o.d -o ${OBJECTDIR}/debug-common.o debug-common.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/debug-common.o.d > ${OBJECTDIR}/debug-common.o.tmp
	${RM} ${OBJECTDIR}/debug-common.o.d 
	${CP} ${OBJECTDIR}/debug-common.o.tmp ${OBJECTDIR}/debug-common.o.d 
	${RM} ${OBJECTDIR}/debug-common.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/debug-common.o.d > ${OBJECTDIR}/debug-common.o.tmp
	${RM} ${OBJECTDIR}/debug-common.o.d 
	${CP} ${OBJECTDIR}/debug-common.o.tmp ${OBJECTDIR}/debug-common.o.d 
	${RM} ${OBJECTDIR}/debug-common.o.tmp
endif
${OBJECTDIR}/sd-spi-cmd.o: sd-spi-cmd.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/sd-spi-cmd.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/sd-spi-cmd.o.d -o ${OBJECTDIR}/sd-spi-cmd.o sd-spi-cmd.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/sd-spi-cmd.o.d > ${OBJECTDIR}/sd-spi-cmd.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-cmd.o.d 
	${CP} ${OBJECTDIR}/sd-spi-cmd.o.tmp ${OBJECTDIR}/sd-spi-cmd.o.d 
	${RM} ${OBJECTDIR}/sd-spi-cmd.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/sd-spi-cmd.o.d > ${OBJECTDIR}/sd-spi-cmd.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-cmd.o.d 
	${CP} ${OBJECTDIR}/sd-spi-cmd.o.tmp ${OBJECTDIR}/sd-spi-cmd.o.d 
	${RM} ${OBJECTDIR}/sd-spi-cmd.o.tmp
endif
${OBJECTDIR}/uartansi.o: uartansi.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/uartansi.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/uartansi.o.d -o ${OBJECTDIR}/uartansi.o uartansi.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/uartansi.o.d > ${OBJECTDIR}/uartansi.o.tmp
	${RM} ${OBJECTDIR}/uartansi.o.d 
	${CP} ${OBJECTDIR}/uartansi.o.tmp ${OBJECTDIR}/uartansi.o.d 
	${RM} ${OBJECTDIR}/uartansi.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/uartansi.o.d > ${OBJECTDIR}/uartansi.o.tmp
	${RM} ${OBJECTDIR}/uartansi.o.d 
	${CP} ${OBJECTDIR}/uartansi.o.tmp ${OBJECTDIR}/uartansi.o.d 
	${RM} ${OBJECTDIR}/uartansi.o.tmp
endif
${OBJECTDIR}/uartstring.o: uartstring.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/uartstring.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/uartstring.o.d -o ${OBJECTDIR}/uartstring.o uartstring.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/uartstring.o.d > ${OBJECTDIR}/uartstring.o.tmp
	${RM} ${OBJECTDIR}/uartstring.o.d 
	${CP} ${OBJECTDIR}/uartstring.o.tmp ${OBJECTDIR}/uartstring.o.d 
	${RM} ${OBJECTDIR}/uartstring.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/uartstring.o.d > ${OBJECTDIR}/uartstring.o.tmp
	${RM} ${OBJECTDIR}/uartstring.o.d 
	${CP} ${OBJECTDIR}/uartstring.o.tmp ${OBJECTDIR}/uartstring.o.d 
	${RM} ${OBJECTDIR}/uartstring.o.tmp
endif
${OBJECTDIR}/mcp23017.o: mcp23017.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/mcp23017.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/mcp23017.o.d -o ${OBJECTDIR}/mcp23017.o mcp23017.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/mcp23017.o.d > ${OBJECTDIR}/mcp23017.o.tmp
	${RM} ${OBJECTDIR}/mcp23017.o.d 
	${CP} ${OBJECTDIR}/mcp23017.o.tmp ${OBJECTDIR}/mcp23017.o.d 
	${RM} ${OBJECTDIR}/mcp23017.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/mcp23017.o.d > ${OBJECTDIR}/mcp23017.o.tmp
	${RM} ${OBJECTDIR}/mcp23017.o.d 
	${CP} ${OBJECTDIR}/mcp23017.o.tmp ${OBJECTDIR}/mcp23017.o.d 
	${RM} ${OBJECTDIR}/mcp23017.o.tmp
endif
${OBJECTDIR}/sd-spi-phy.o: sd-spi-phy.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/sd-spi-phy.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE) -g -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/sd-spi-phy.o.d -o ${OBJECTDIR}/sd-spi-phy.o sd-spi-phy.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/sd-spi-phy.o.d > ${OBJECTDIR}/sd-spi-phy.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-phy.o.d 
	${CP} ${OBJECTDIR}/sd-spi-phy.o.tmp ${OBJECTDIR}/sd-spi-phy.o.d 
	${RM} ${OBJECTDIR}/sd-spi-phy.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/sd-spi-phy.o.d > ${OBJECTDIR}/sd-spi-phy.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-phy.o.d 
	${CP} ${OBJECTDIR}/sd-spi-phy.o.tmp ${OBJECTDIR}/sd-spi-phy.o.d 
	${RM} ${OBJECTDIR}/sd-spi-phy.o.tmp
endif
else
${OBJECTDIR}/sd-spi-dma.o: sd-spi-dma.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/sd-spi-dma.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/sd-spi-dma.o.d -o ${OBJECTDIR}/sd-spi-dma.o sd-spi-dma.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/sd-spi-dma.o.d > ${OBJECTDIR}/sd-spi-dma.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-dma.o.d 
	${CP} ${OBJECTDIR}/sd-spi-dma.o.tmp ${OBJECTDIR}/sd-spi-dma.o.d 
	${RM} ${OBJECTDIR}/sd-spi-dma.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/sd-spi-dma.o.d > ${OBJECTDIR}/sd-spi-dma.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-dma.o.d 
	${CP} ${OBJECTDIR}/sd-spi-dma.o.tmp ${OBJECTDIR}/sd-spi-dma.o.d 
	${RM} ${OBJECTDIR}/sd-spi-dma.o.tmp
endif
${OBJECTDIR}/ecan.o: ecan.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/ecan.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/ecan.o.d -o ${OBJECTDIR}/ecan.o ecan.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/ecan.o.d > ${OBJECTDIR}/ecan.o.tmp
	${RM} ${OBJECTDIR}/ecan.o.d 
	${CP} ${OBJECTDIR}/ecan.o.tmp ${OBJECTDIR}/ecan.o.d 
	${RM} ${OBJECTDIR}/ecan.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/ecan.o.d > ${OBJECTDIR}/ecan.o.tmp
	${RM} ${OBJECTDIR}/ecan.o.d 
	${CP} ${OBJECTDIR}/ecan.o.tmp ${OBJECTDIR}/ecan.o.d 
	${RM} ${OBJECTDIR}/ecan.o.tmp
endif
${OBJECTDIR}/sd-spi.o: sd-spi.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/sd-spi.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/sd-spi.o.d -o ${OBJECTDIR}/sd-spi.o sd-spi.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/sd-spi.o.d > ${OBJECTDIR}/sd-spi.o.tmp
	${RM} ${OBJECTDIR}/sd-spi.o.d 
	${CP} ${OBJECTDIR}/sd-spi.o.tmp ${OBJECTDIR}/sd-spi.o.d 
	${RM} ${OBJECTDIR}/sd-spi.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/sd-spi.o.d > ${OBJECTDIR}/sd-spi.o.tmp
	${RM} ${OBJECTDIR}/sd-spi.o.d 
	${CP} ${OBJECTDIR}/sd-spi.o.tmp ${OBJECTDIR}/sd-spi.o.d 
	${RM} ${OBJECTDIR}/sd-spi.o.tmp
endif
${OBJECTDIR}/i2c-phy.o: i2c-phy.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/i2c-phy.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/i2c-phy.o.d -o ${OBJECTDIR}/i2c-phy.o i2c-phy.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/i2c-phy.o.d > ${OBJECTDIR}/i2c-phy.o.tmp
	${RM} ${OBJECTDIR}/i2c-phy.o.d 
	${CP} ${OBJECTDIR}/i2c-phy.o.tmp ${OBJECTDIR}/i2c-phy.o.d 
	${RM} ${OBJECTDIR}/i2c-phy.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/i2c-phy.o.d > ${OBJECTDIR}/i2c-phy.o.tmp
	${RM} ${OBJECTDIR}/i2c-phy.o.d 
	${CP} ${OBJECTDIR}/i2c-phy.o.tmp ${OBJECTDIR}/i2c-phy.o.d 
	${RM} ${OBJECTDIR}/i2c-phy.o.tmp
endif
${OBJECTDIR}/timer.o: timer.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/timer.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/timer.o.d -o ${OBJECTDIR}/timer.o timer.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/timer.o.d > ${OBJECTDIR}/timer.o.tmp
	${RM} ${OBJECTDIR}/timer.o.d 
	${CP} ${OBJECTDIR}/timer.o.tmp ${OBJECTDIR}/timer.o.d 
	${RM} ${OBJECTDIR}/timer.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/timer.o.d > ${OBJECTDIR}/timer.o.tmp
	${RM} ${OBJECTDIR}/timer.o.d 
	${CP} ${OBJECTDIR}/timer.o.tmp ${OBJECTDIR}/timer.o.d 
	${RM} ${OBJECTDIR}/timer.o.tmp
endif
${OBJECTDIR}/uart.o: uart.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/uart.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/uart.o.d -o ${OBJECTDIR}/uart.o uart.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/uart.o.d > ${OBJECTDIR}/uart.o.tmp
	${RM} ${OBJECTDIR}/uart.o.d 
	${CP} ${OBJECTDIR}/uart.o.tmp ${OBJECTDIR}/uart.o.d 
	${RM} ${OBJECTDIR}/uart.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/uart.o.d > ${OBJECTDIR}/uart.o.tmp
	${RM} ${OBJECTDIR}/uart.o.d 
	${CP} ${OBJECTDIR}/uart.o.tmp ${OBJECTDIR}/uart.o.d 
	${RM} ${OBJECTDIR}/uart.o.tmp
endif
${OBJECTDIR}/fat32.o: fat32.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/fat32.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/fat32.o.d -o ${OBJECTDIR}/fat32.o fat32.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/fat32.o.d > ${OBJECTDIR}/fat32.o.tmp
	${RM} ${OBJECTDIR}/fat32.o.d 
	${CP} ${OBJECTDIR}/fat32.o.tmp ${OBJECTDIR}/fat32.o.d 
	${RM} ${OBJECTDIR}/fat32.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/fat32.o.d > ${OBJECTDIR}/fat32.o.tmp
	${RM} ${OBJECTDIR}/fat32.o.d 
	${CP} ${OBJECTDIR}/fat32.o.tmp ${OBJECTDIR}/fat32.o.d 
	${RM} ${OBJECTDIR}/fat32.o.tmp
endif
${OBJECTDIR}/fat32-file.o: fat32-file.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/fat32-file.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/fat32-file.o.d -o ${OBJECTDIR}/fat32-file.o fat32-file.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/fat32-file.o.d > ${OBJECTDIR}/fat32-file.o.tmp
	${RM} ${OBJECTDIR}/fat32-file.o.d 
	${CP} ${OBJECTDIR}/fat32-file.o.tmp ${OBJECTDIR}/fat32-file.o.d 
	${RM} ${OBJECTDIR}/fat32-file.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/fat32-file.o.d > ${OBJECTDIR}/fat32-file.o.tmp
	${RM} ${OBJECTDIR}/fat32-file.o.d 
	${CP} ${OBJECTDIR}/fat32-file.o.tmp ${OBJECTDIR}/fat32-file.o.d 
	${RM} ${OBJECTDIR}/fat32-file.o.tmp
endif
${OBJECTDIR}/main.o: main.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/main.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/main.o.d -o ${OBJECTDIR}/main.o main.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/main.o.d > ${OBJECTDIR}/main.o.tmp
	${RM} ${OBJECTDIR}/main.o.d 
	${CP} ${OBJECTDIR}/main.o.tmp ${OBJECTDIR}/main.o.d 
	${RM} ${OBJECTDIR}/main.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/main.o.d > ${OBJECTDIR}/main.o.tmp
	${RM} ${OBJECTDIR}/main.o.d 
	${CP} ${OBJECTDIR}/main.o.tmp ${OBJECTDIR}/main.o.d 
	${RM} ${OBJECTDIR}/main.o.tmp
endif
${OBJECTDIR}/sd-spi-debug.o: sd-spi-debug.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/sd-spi-debug.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/sd-spi-debug.o.d -o ${OBJECTDIR}/sd-spi-debug.o sd-spi-debug.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/sd-spi-debug.o.d > ${OBJECTDIR}/sd-spi-debug.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-debug.o.d 
	${CP} ${OBJECTDIR}/sd-spi-debug.o.tmp ${OBJECTDIR}/sd-spi-debug.o.d 
	${RM} ${OBJECTDIR}/sd-spi-debug.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/sd-spi-debug.o.d > ${OBJECTDIR}/sd-spi-debug.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-debug.o.d 
	${CP} ${OBJECTDIR}/sd-spi-debug.o.tmp ${OBJECTDIR}/sd-spi-debug.o.d 
	${RM} ${OBJECTDIR}/sd-spi-debug.o.tmp
endif
${OBJECTDIR}/uart-dma.o: uart-dma.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/uart-dma.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/uart-dma.o.d -o ${OBJECTDIR}/uart-dma.o uart-dma.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/uart-dma.o.d > ${OBJECTDIR}/uart-dma.o.tmp
	${RM} ${OBJECTDIR}/uart-dma.o.d 
	${CP} ${OBJECTDIR}/uart-dma.o.tmp ${OBJECTDIR}/uart-dma.o.d 
	${RM} ${OBJECTDIR}/uart-dma.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/uart-dma.o.d > ${OBJECTDIR}/uart-dma.o.tmp
	${RM} ${OBJECTDIR}/uart-dma.o.d 
	${CP} ${OBJECTDIR}/uart-dma.o.tmp ${OBJECTDIR}/uart-dma.o.d 
	${RM} ${OBJECTDIR}/uart-dma.o.tmp
endif
${OBJECTDIR}/fat32-file-opt.o: fat32-file-opt.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/fat32-file-opt.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/fat32-file-opt.o.d -o ${OBJECTDIR}/fat32-file-opt.o fat32-file-opt.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/fat32-file-opt.o.d > ${OBJECTDIR}/fat32-file-opt.o.tmp
	${RM} ${OBJECTDIR}/fat32-file-opt.o.d 
	${CP} ${OBJECTDIR}/fat32-file-opt.o.tmp ${OBJECTDIR}/fat32-file-opt.o.d 
	${RM} ${OBJECTDIR}/fat32-file-opt.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/fat32-file-opt.o.d > ${OBJECTDIR}/fat32-file-opt.o.tmp
	${RM} ${OBJECTDIR}/fat32-file-opt.o.d 
	${CP} ${OBJECTDIR}/fat32-file-opt.o.tmp ${OBJECTDIR}/fat32-file-opt.o.d 
	${RM} ${OBJECTDIR}/fat32-file-opt.o.tmp
endif
${OBJECTDIR}/debug-common.o: debug-common.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/debug-common.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/debug-common.o.d -o ${OBJECTDIR}/debug-common.o debug-common.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/debug-common.o.d > ${OBJECTDIR}/debug-common.o.tmp
	${RM} ${OBJECTDIR}/debug-common.o.d 
	${CP} ${OBJECTDIR}/debug-common.o.tmp ${OBJECTDIR}/debug-common.o.d 
	${RM} ${OBJECTDIR}/debug-common.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/debug-common.o.d > ${OBJECTDIR}/debug-common.o.tmp
	${RM} ${OBJECTDIR}/debug-common.o.d 
	${CP} ${OBJECTDIR}/debug-common.o.tmp ${OBJECTDIR}/debug-common.o.d 
	${RM} ${OBJECTDIR}/debug-common.o.tmp
endif
${OBJECTDIR}/sd-spi-cmd.o: sd-spi-cmd.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/sd-spi-cmd.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/sd-spi-cmd.o.d -o ${OBJECTDIR}/sd-spi-cmd.o sd-spi-cmd.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/sd-spi-cmd.o.d > ${OBJECTDIR}/sd-spi-cmd.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-cmd.o.d 
	${CP} ${OBJECTDIR}/sd-spi-cmd.o.tmp ${OBJECTDIR}/sd-spi-cmd.o.d 
	${RM} ${OBJECTDIR}/sd-spi-cmd.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/sd-spi-cmd.o.d > ${OBJECTDIR}/sd-spi-cmd.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-cmd.o.d 
	${CP} ${OBJECTDIR}/sd-spi-cmd.o.tmp ${OBJECTDIR}/sd-spi-cmd.o.d 
	${RM} ${OBJECTDIR}/sd-spi-cmd.o.tmp
endif
${OBJECTDIR}/uartansi.o: uartansi.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/uartansi.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/uartansi.o.d -o ${OBJECTDIR}/uartansi.o uartansi.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/uartansi.o.d > ${OBJECTDIR}/uartansi.o.tmp
	${RM} ${OBJECTDIR}/uartansi.o.d 
	${CP} ${OBJECTDIR}/uartansi.o.tmp ${OBJECTDIR}/uartansi.o.d 
	${RM} ${OBJECTDIR}/uartansi.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/uartansi.o.d > ${OBJECTDIR}/uartansi.o.tmp
	${RM} ${OBJECTDIR}/uartansi.o.d 
	${CP} ${OBJECTDIR}/uartansi.o.tmp ${OBJECTDIR}/uartansi.o.d 
	${RM} ${OBJECTDIR}/uartansi.o.tmp
endif
${OBJECTDIR}/uartstring.o: uartstring.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/uartstring.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/uartstring.o.d -o ${OBJECTDIR}/uartstring.o uartstring.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/uartstring.o.d > ${OBJECTDIR}/uartstring.o.tmp
	${RM} ${OBJECTDIR}/uartstring.o.d 
	${CP} ${OBJECTDIR}/uartstring.o.tmp ${OBJECTDIR}/uartstring.o.d 
	${RM} ${OBJECTDIR}/uartstring.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/uartstring.o.d > ${OBJECTDIR}/uartstring.o.tmp
	${RM} ${OBJECTDIR}/uartstring.o.d 
	${CP} ${OBJECTDIR}/uartstring.o.tmp ${OBJECTDIR}/uartstring.o.d 
	${RM} ${OBJECTDIR}/uartstring.o.tmp
endif
${OBJECTDIR}/mcp23017.o: mcp23017.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/mcp23017.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/mcp23017.o.d -o ${OBJECTDIR}/mcp23017.o mcp23017.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/mcp23017.o.d > ${OBJECTDIR}/mcp23017.o.tmp
	${RM} ${OBJECTDIR}/mcp23017.o.d 
	${CP} ${OBJECTDIR}/mcp23017.o.tmp ${OBJECTDIR}/mcp23017.o.d 
	${RM} ${OBJECTDIR}/mcp23017.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/mcp23017.o.d > ${OBJECTDIR}/mcp23017.o.tmp
	${RM} ${OBJECTDIR}/mcp23017.o.d 
	${CP} ${OBJECTDIR}/mcp23017.o.tmp ${OBJECTDIR}/mcp23017.o.d 
	${RM} ${OBJECTDIR}/mcp23017.o.tmp
endif
${OBJECTDIR}/sd-spi-phy.o: sd-spi-phy.c  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} ${OBJECTDIR} 
	${RM} ${OBJECTDIR}/sd-spi-phy.o.d 
	${MP_CC} $(MP_EXTRA_CC_PRE)  -omf=elf -x c -c -mcpu=$(MP_PROCESSOR_OPTION) -fno-short-double -O1 -MMD -MF ${OBJECTDIR}/sd-spi-phy.o.d -o ${OBJECTDIR}/sd-spi-phy.o sd-spi-phy.c  
ifneq (,$(findstring MINGW32,$(OS_CURRENT))) 
	@sed -e 's/\"//g' -e 's/\\$$/__EOL__/g' -e 's/\\ /__ESCAPED_SPACES__/g' -e 's/\\/\//g' -e 's/__ESCAPED_SPACES__/\\ /g' -e 's/__EOL__$$/\\/g' ${OBJECTDIR}/sd-spi-phy.o.d > ${OBJECTDIR}/sd-spi-phy.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-phy.o.d 
	${CP} ${OBJECTDIR}/sd-spi-phy.o.tmp ${OBJECTDIR}/sd-spi-phy.o.d 
	${RM} ${OBJECTDIR}/sd-spi-phy.o.tmp}
else 
	@sed -e 's/\"//g' ${OBJECTDIR}/sd-spi-phy.o.d > ${OBJECTDIR}/sd-spi-phy.o.tmp
	${RM} ${OBJECTDIR}/sd-spi-phy.o.d 
	${CP} ${OBJECTDIR}/sd-spi-phy.o.tmp ${OBJECTDIR}/sd-spi-phy.o.d 
	${RM} ${OBJECTDIR}/sd-spi-phy.o.tmp
endif
endif

# ------------------------------------------------------------------------------------
# Rules for buildStep: link
ifeq ($(TYPE_IMAGE), DEBUG_RUN)
dist/${CND_CONF}/${IMAGE_TYPE}/calsol-datalogger-pic24h.X.${IMAGE_TYPE}.elf: ${OBJECTFILES}  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} dist/${CND_CONF}/${IMAGE_TYPE} 
	${MP_CC} $(MP_EXTRA_LD_PRE)  -omf=elf  -mcpu=$(MP_PROCESSOR_OPTION)  -D__DEBUG -D__MPLAB_DEBUGGER_PICKIT2=1 -o dist/${CND_CONF}/${IMAGE_TYPE}/calsol-datalogger-pic24h.X.${IMAGE_TYPE}.elf ${OBJECTFILES}        -Wl,--defsym=__MPLAB_BUILD=1,--heap=1024,--stack=1024,--report-mem$(MP_EXTRA_LD_POST)$(MP_LINKER_FILE_OPTION),--defsym=__MPLAB_DEBUG=1,--defsym=__ICD2RAM=1,--defsym=__DEBUG=1,--defsym=__MPLAB_DEBUGGER_PICKIT2=1
else
dist/${CND_CONF}/${IMAGE_TYPE}/calsol-datalogger-pic24h.X.${IMAGE_TYPE}.elf: ${OBJECTFILES}  nbproject/Makefile-${CND_CONF}.mk
	${MKDIR} dist/${CND_CONF}/${IMAGE_TYPE} 
	${MP_CC} $(MP_EXTRA_LD_PRE)  -omf=elf  -mcpu=$(MP_PROCESSOR_OPTION)  -o dist/${CND_CONF}/${IMAGE_TYPE}/calsol-datalogger-pic24h.X.${IMAGE_TYPE}.elf ${OBJECTFILES}        -Wl,--defsym=__MPLAB_BUILD=1,--heap=1024,--stack=1024,--report-mem$(MP_EXTRA_LD_POST)$(MP_LINKER_FILE_OPTION)
	${MP_CC_DIR}\\pic30-bin2hex dist/${CND_CONF}/${IMAGE_TYPE}/calsol-datalogger-pic24h.X.${IMAGE_TYPE}.elf -omf=elf
endif


# Subprojects
.build-subprojects:

# Clean Targets
.clean-conf:
	${RM} -r build/default
	${RM} -r dist/default

# Enable dependency checking
.dep.inc: .depcheck-impl

include .dep.inc
