#include "ECCO_OPTIONS.h"
#include "AD_CONFIG.h"
#ifdef ALLOW_CTRL
# include "CTRL_OPTIONS.h"
#endif

      SUBROUTINE ECCO_COST_INIT_FIXED( myThid )

c     ==================================================================
c     SUBROUTINE ecco_cost_init_fixed
c     ==================================================================
c
c     o Set contributions to the cost function and the cost function
c       itself to zero. The cost function and the individual contribu-
c       tions are defined in the header file "ecco_cost.h".
c
c     started: Christian Eckert eckert@mit.edu 30-Jun-1999
c
c     changed: Christian Eckert eckert@mit.edu 25-Feb-2000
c
c              - Restructured the code in order to create a package
c                for the MITgcmUV.
c
c     changed: Ralf Giering 18-Jan-2001
c
c              - move namelist reading to cost_readparms.F
c
c     ==================================================================
c     SUBROUTINE ecco_cost_init_fixed
c     ==================================================================

      IMPLICIT NONE

c     == global variables ==
#include "EEPARAMS.h"
#include "SIZE.h"
#include "GRID.h"
#include "PARAMS.h"

#ifdef ALLOW_CAL
# include "cal.h"
#endif
#include "ECCO_SIZE.h"
#include "ECCO.h"
#ifdef ALLOW_CTRL
# include "OPTIMCYCLE.h"
#endif

c     == routine arguments ==
      integer myThid

c     == external functions ==
      integer  ifnblnk
      external ifnblnk
      integer  ilnblnk
      external ilnblnk
#ifdef ALLOW_CAL
      integer  cal_IntYears
      external cal_IntYears
      integer  cal_IntMonths
      external cal_IntMonths
      integer  cal_IntDays
      external cal_IntDays
#endif

c     == local variables ==
      integer k
      logical exst
      _RL     missingObsFlag
      PARAMETER ( missingObsFlag = 1. _d 23 )
#ifdef ALLOW_GENCOST_1D
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      integer ilo, ihi, irec, gwunit
#endif
#ifdef ALLOW_GENCOST_CONTRIBUTION
      integer k2
#endif
#ifndef ECCO_VARIABLE_AREAVOLGLOB
      INTEGER i, j, bi, bj
#endif
c     == end of interface ==

      _BEGIN_MASTER(myThid)
#ifdef ALLOW_CTRL
      eccoiter=optimcycle
#else
      eccoiter=0
#endif
      eccoWriteCostFunction = .TRUE.
      _END_MASTER(myThid)

#ifndef ECCO_VARIABLE_AREAVOLGLOB
      DO bj=myByLo(myThid),myByHi(myThid)
        DO bi=myBxLo(myThid),myBxHi(myThid)
          DO k = 1,Nr
            DO j = 1-OLy,sNy+OLy
              DO i = 1-OLx,sNx+OLx
                eccoVol_0(i,j,k,bi,bj)=
     &          hFacC(i,j,k,bi,bj)*drF(k)*rA(i,j,bi,bj)
              ENDDO
            ENDDO
          ENDDO
        ENDDO
      ENDDO
#endif

#ifdef ALLOW_CAL

c--   The number of monthly and daily averages generated by the
c--   current model integration.
      nyearsrec = cal_IntYears( myThid )
      nmonsrec = cal_IntMonths( myThid )
      ndaysrec = cal_IntDays( myThid )

#ifdef ALLOW_GENCOST_CONTRIBUTION
      do k = 1, NGENCOST

c--    skip averaging when several cost terms use the
c      same barfile or when barfile is undefined
       gencost_barskip(k)=.FALSE.
       if ( gencost_barfile(k).EQ.' ' )
     &      gencost_barskip(k)=.TRUE.
       do k2 = 1,k-1
         if ( gencost_barfile(k2).EQ.gencost_barfile(k) )
     &      gencost_barskip(k)=.TRUE.
       enddo

c--    set time averaging parameters
       if ( (using_gencost(k)).AND.( (gencost_flag(k).GE.1).OR.
     &         (gencost_avgperiod(k).NE.'     ') ) ) then
         if ( gencost_avgperiod(k) .EQ. 'day' .OR.
     &        gencost_avgperiod(k) .EQ. 'DAY' ) then
            gencost_nrec(k)   = ndaysrec
            gencost_period(k) = 86400.
         else if ( gencost_avgperiod(k) .EQ. 'month' .OR.
     &        gencost_avgperiod(k) .EQ. 'MONTH' ) then
            gencost_nrec(k)   =nmonsrec
            gencost_period(k) = 0.
         else if ( gencost_avgperiod(k) .EQ. 'step' .OR.
     &        gencost_avgperiod(k) .EQ. 'STEP' ) then
            gencost_nrec(k)   =nTimeSteps+1
            gencost_period(k) = dTtracerLev(1)
         else if ( gencost_avgperiod(k) .EQ. 'const' .OR.
     &        gencost_avgperiod(k) .EQ. 'CONST' ) then
            gencost_nrec(k)   =1
            gencost_period(k) = dTtracerLev(1)
         else if ( gencost_avgperiod(k) .EQ. 'year' .OR.
     &        gencost_avgperiod(k) .EQ. 'YEAR' ) then
           STOP
     &      'ecco_cost_init_fixed: yearly data not yet implemented'
         else
           STOP
     &      'ecco_cost_init_fixed: gencost_avgperiod wrongly specified'
         endif
       endif

c--    set observation start/enddate
       if (gencost_startdate1(k).GT.0) then
         call cal_FullDate(
     &     gencost_startdate1(k), gencost_startdate2(k),
     &     gencost_startdate(1,k), myThid )
       else
         call cal_CopyDate(modelStartDate,
     &     gencost_startdate(1,k),myThid)
         gencost_startdate1(k)=startdate_1
         gencost_startdate2(k)=startdate_2
       endif

       if (gencost_enddate1(k).GT.0) then
         call cal_FullDate(
     &     gencost_enddate1(k), gencost_enddate2(k),
     &     gencost_enddate(1,k), myThid )
       else
         call cal_CopyDate(modelEndDate,
     &     gencost_enddate(1,k),myThid)
       endif

#ifdef ALLOW_GENCOST_1D
      if ( (gencost_name(k).EQ.'gmbp') .OR.
     &     (gencost_name(k).EQ.'gmsl')) then
       if(gencost_nrec(k).GT.N1DDATA)then
        WRITE(msgBuf,'(2A,2i8)') 'ecco_cost_init_fixed: ',
     &   'Increase N1DDATA', N1DDATA, gencost_nrec(k)
        CALL PRINT_ERROR( msgBuf, myThid)
       endif

      do irec = 1, N1DDATA
       gencost_1DDATA(irec,k) = 0. _d 0
      enddo

      if(gencost_wei1d(k).NE.0. _d 0)then
        gencost_wei1d(k) = 1. _d 0 / gencost_wei1d(k)
     &      /gencost_wei1d(k)
      endif

      if ( gencost_datafile(k) .NE. ' ' ) then
      ilo = ifnblnk(gencost_datafile(k))
      ihi = ilnblnk(gencost_datafile(k))

      CALL OPEN_COPY_DATA_FILE(
     I                          gencost_datafile(k)(ilo:ihi),
     I                          'ECCO_COST_INIT_FIXED: ',
     O                          gwunit,
     I                          myThid )
      do irec = 1, gencost_nrec(k)
         read(gwunit,*) gencost_1DDATA(irec,k)
      enddo
      close(gwunit)
      endif

      endif
#endif /* ALLOW_GENCOST_1D */

      enddo !do k = 1, NGENCOST
#endif /* ALLOW_GENCOST_CONTRIBUTION */

#endif /* ALLOW_CAL */

C-    ECCO_CHECK is now called from packages_check.F
c     call ecco_check( myThid )

c--   Get the weights that are to be used for the individual cost
c--   function contributions.
      call ecco_cost_weights( myThid )

c--   Initialise adjoint of monthly mean files calculated
c--   in cost_averagesfields (and their ad...).
cph(
cph   The following init. shoud not be applied if in the middle
cph   of a divided adjoint run
cph)
#ifndef ALLOW_TANGENTLINEAR_RUN
cph!!! and I think it needs to be seen by TAF
cph!!! for repeated TLM runs
cph!!!
      inquire( file='costfinal', exist=exst )
      if ( .NOT. exst) then
         call ecco_cost_init_barfiles( myThid )
      endif
#endif

c--   Summarize the cost function setup. <-- now called at the end of ECCO_CHECK
c     call ecco_summary( myThid )

      _BARRIER

      RETURN
      END
