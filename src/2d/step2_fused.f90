!> Compute all fluxes at cell edges 
!! \param qold[in] solution array for computing fluxes. It is not changed in this subroutine
!! \param fm[out] fluxes on the left side of each vertical edge
!! \param fp[out] fluxes on the right side of each vertical edge
!! \param gm[out] fluxes on the lower side of each horizontal edge
!! \param gp[out] fluxes on the upper side of each horizontal edge
subroutine step2_fused(maxm,meqn,maux,mbc,mx,my,qold,aux,dx,dy,dt,cflgrid,fm,fp,gm,gp,rpn2,rpt2)
!
!     clawpack routine ...  modified for AMRCLAW
!
!     Take one time step, updating q.
!     On entry, qold gives
!        initial data for this step
!        and is unchanged in this version.
!    
!     fm, fp are fluxes to left and right of single cell edge
!     See the flux2 documentation for more information.
!
!     Converted to f90 2012-1-04 (KTM)
!
    
    use amr_module
    use parallel_advanc_module, only: dtcom, dxcom, dycom, icom, jcom

    implicit none
    
    external rpn2, rpt2
    
    ! Arguments
    integer, intent(in) :: maxm,meqn,maux,mbc,mx,my
    real(kind=8), intent(in) :: dx,dy,dt
    real(kind=8), intent(inout) :: cflgrid
    real(kind=8), intent(inout) :: qold(meqn, 1-mbc:mx+mbc, 1-mbc:my+mbc)
    real(kind=8), intent(inout) :: aux(maux,1-mbc:mx+mbc, 1-mbc:my+mbc)
    real(kind=8), intent(inout) :: fm(meqn, 1-mbc:mx+mbc, 1-mbc:my+mbc)
    real(kind=8), intent(inout) :: fp(meqn,1-mbc:mx+mbc, 1-mbc:my+mbc)
    real(kind=8), intent(inout) :: gm(meqn,1-mbc:mx+mbc, 1-mbc:my+mbc)
    real(kind=8), intent(inout) :: gp(meqn,1-mbc:mx+mbc, 1-mbc:my+mbc)
    
    ! Local storage for flux accumulation
    real(kind=8) :: faddm(meqn,1-mbc:maxm+mbc)
    real(kind=8) :: faddp(meqn,1-mbc:maxm+mbc)
    real(kind=8) :: gaddm(meqn,1-mbc:maxm+mbc,2)
    real(kind=8) :: gaddp(meqn,1-mbc:maxm+mbc,2)
    
    ! Scratch storage for Sweeps and Riemann problems
    real(kind=8) ::  q1d(meqn,1-mbc:maxm+mbc)
    real(kind=8) :: aux1(maux,1-mbc:maxm+mbc)
    real(kind=8) :: aux2(maux,1-mbc:maxm+mbc)
    real(kind=8) :: aux3(maux,1-mbc:maxm+mbc)
    real(kind=8) :: dtdx1d(1-mbc:maxm+mbc)
    real(kind=8) :: dtdy1d(1-mbc:maxm+mbc)
    
    real(kind=8) ::     s(mwaves, 1-mbc:maxm + mbc)
    real(kind=8) :: bmadq(meqn,1-mbc:maxm + mbc)
    real(kind=8) :: bpadq(meqn,1-mbc:maxm + mbc)
    
    ! Looping scalar storage
    integer :: i,j,thread_num
    real(kind=8) :: dtdx,dtdy,cfl1d

    ! Local variables for the Riemann solver
    real(kind=8) :: delta1, delta2, a1, a2
    integer :: m, mw, mu, mv
    real(kind=8) :: rho, bulk, cc, zz
    real(kind=8) :: wave_x(meqn, mwaves, 1-mbc:mx+mbc)
    real(kind=8) :: wave_y(meqn, mwaves, 1-mbc:my+mbc)
    real(kind=8) :: amdq(meqn,1-mbc:mx + mbc)
    real(kind=8) :: apdq(meqn,1-mbc:mx + mbc)
    real(kind=8) :: bmdq(meqn,1-mbc:my + mbc)
    real(kind=8) :: bpdq(meqn,1-mbc:my + mbc)
    ! For 2nd order corrections
    real(kind=8) :: wave_x_tmp(meqn, mwaves, 1-mbc:mx+mbc)
    real(kind=8) :: wave_y_tmp(meqn, mwaves, 1-mbc:my+mbc)
    real(kind=8) :: dot, wnorm2, wlimitr, dtdxave, dtdyave, abs_sign, c, r
    real(kind=8) :: cqxx(meqn,1-mbc:mx + mbc)
    real(kind=8) :: cqyy(meqn,1-mbc:my + mbc)
    logical limit

    common /cparam/ rho,bulk,cc,zz

    
    ! Common block storage
    ! integer :: icom,jcom
    ! real(kind=8) :: dtcom,dxcom,dycom,tcom
    ! common /comxyt/ dtcom,dxcom,dycom,tcom,icom,jcom
    
    ! Store mesh parameters in common block
    dxcom = dx
    dycom = dy
    dtcom = dt
    
    cflgrid = 0.d0
    dtdx = dt/dx
    dtdy = dt/dy

    fm = 0.d0
    fp = 0.d0
    gm = 0.d0
    gp = 0.d0

    limit = .false.
    do mw=1,mwaves
        if (mthlim(mw) .gt. 0) limit = .true.
    enddo
    
    ! ============================================================================
    ! Perform X-Sweeps
    do j = 0,my+1
        ! Set dtdx slice if a capacity array exists
        if (mcapa > 0)  then
            dtdx1d(1-mbc:mx+mbc) = dtdx / aux(mcapa,1-mbc:mx+mbc,j)
        else
            dtdx1d = dtdx
        endif

        do i = 2-mbc, mx+mbc
            ! solve Riemann problem between cell (i-1,j) and (i,j)
            mu = 2
            mv = 3
            delta1 = qold(1,i,j) - qold(1,i-1,j)
            delta2 = qold(mu,i,j) - qold(mu,i-1,j)
            a1 = (-delta1 + zz*delta2) / (2.d0*zz)
            a2 = (delta1 + zz*delta2) / (2.d0*zz)
            !        # Compute the waves.
            wave_x(1,1,i) = -a1*zz
            wave_x(mu,1,i) = a1
            wave_x(mv,1,i) = 0.d0
            s(1,i) = -cc

            wave_x(1,2,i) = a2*zz
            wave_x(mu,2,i) = a2
            wave_x(mv,2,i) = 0.d0
            s(2,i) = cc
            do m = 1,meqn
                amdq(m,i) = s(1,i)*wave_x(m,1,i)
                apdq(m,i) = s(2,i)*wave_x(m,2,i)
                fm(m,i,j) = fm(m,i,j) + amdq(m,i)
                fp(m,i,j) = fp(m,i,j) - apdq(m,i)
            enddo
            do mw=1,mwaves
                cflgrid = dmax1(cflgrid, dtdx1d(i)*s(mw,i),-dtdx1d(i-1)*s(mw,i))
            enddo
        enddo

!     -----------------------------------------------------------
!     # modify F fluxes for second order q_{xx} correction terms:
!     -----------------------------------------------------------
        if (method(2).ne.1) then ! if second-order
            ! # apply limiter to waves:
            if (limit) then ! limiter if
                wave_x_tmp = wave_x
                do mw=1,mwaves ! mwaves loop
                    do i = 1, mx+1 ! mx loop
                        if (mthlim(mw) .eq. 0) cycle
                        dot = 0.d0
                        wnorm2 = 0.d0
                        do m=1,meqn
                            wnorm2 = wnorm2 + wave_x_tmp(m,mw,i)**2
                        enddo
                        if (wnorm2.eq.0.d0) cycle

                        if (s(mw,i) .gt. 0.d0) then
                            do m=1,meqn
                                dot = dot + wave_x_tmp(m,mw,i)*wave_x_tmp(m,mw,i-1)
                            enddo
                        else
                            do m=1,meqn
                                dot = dot + wave_x_tmp(m,mw,i)*wave_x_tmp(m,mw,i+1)
                            enddo
                        endif

                        r = dot / wnorm2

                        ! choose limiter
                        if (mthlim(mw) .eq. 1) then
                            !               --------
                            !               # minmod
                            !               --------
                            wlimitr = dmax1(0.d0, dmin1(1.d0, r))

                        else if (mthlim(mw) .eq. 2) then
                            !               ----------
                            !               # superbee
                            !               ----------
                            wlimitr = dmax1(0.d0, dmin1(1.d0, 2.d0*r), dmin1(2.d0, r))

                        else if (mthlim(mw) .eq. 3) then
                            !               ----------
                            !               # van Leer
                            !               ----------
                            wlimitr = (r + dabs(r)) / (1.d0 + dabs(r))

                        else if (mthlim(mw) .eq. 4) then
                            !               ------------------------------
                            !               # monotinized centered
                            !               ------------------------------
                            c = (1.d0 + r)/2.d0
                            wlimitr = dmax1(0.d0, dmin1(c, 2.d0, 2.d0*r))
                        else if (mthlim(mw) .eq. 5) then
                            !               ------------------------------
                            !               # Beam-Warming
                            !               ------------------------------
                            wlimitr = r
                        else
                            print *, 'Unrecognized limiter.'
                            stop
                        endif
                        !
                        !  # apply limiter to waves:
                        !
                        do m=1,meqn
                            wave_x(m,mw,i) = wlimitr * wave_x(m,mw,i)
                        enddo
                    enddo ! end mx loop
                enddo ! end mwave loop
            endif ! end limiter if
            do i = 1, mx+1 ! mx loop
                !        # For correction terms below, need average of dtdx in cell
                !        # i-1 and i.  Compute these and overwrite dtdx1d:
                !
                !        # modified in Version 4.3 to use average only in cqxx, not transverse
                dtdxave = 0.5d0 * (dtdx1d(i-1) + dtdx1d(i))
                ! second order corrections:
                do m=1,meqn
                    cqxx(m,i) = 0.d0
                    do mw=1,mwaves
                        if (use_fwaves) then
                            abs_sign = dsign(1.d0,s(mw,i))
                        else
                            abs_sign = dabs(s(mw,i))
                        endif

                        cqxx(m,i) = cqxx(m,i) + abs_sign * &
                            (1.d0 - dabs(s(mw,i))*dtdxave) * wave_x(m,mw,i)
                    enddo
                    fp(m,i,j) = fp(m,i,j) + 0.5d0 * cqxx(m,i)
                    fm(m,i,j) = fm(m,i,j) + 0.5d0 * cqxx(m,i)
                enddo
            enddo ! end mx loop
        endif ! end if second-order 
!     -----------------------------------------------------------
!     # END modify F fluxes for second order q_{xx} correction terms:
!     -----------------------------------------------------------
    enddo

    ! ============================================================================
    !  y-sweeps    
    do i = 0,mx+1
        ! Set dtdx slice if a capacity array exists
        if (mcapa > 0) then
            dtdy1d(1-mbc:my+mbc) = dtdy / aux(mcapa,i,1-mbc:my+mbc)
        else
            dtdy1d = dtdy
        endif

        do j = 2-mbc, my+mbc
            ! solve Riemann problem between cell (i,j-1) and (i,j)
            mu = 3
            mv = 2
            delta1 = qold(1,i,j) - qold(1,i,j-1)
            delta2 = qold(mu,i,j) - qold(mu,i,j-1)
            a1 = (-delta1 + zz*delta2) / (2.d0*zz)
            a2 = (delta1 + zz*delta2) / (2.d0*zz)
            !        # Compute the waves.
            wave_y(1,1,j) = -a1*zz
            wave_y(mu,1,j) = a1
            wave_y(mv,1,j) = 0.d0
            s(1,j) = -cc

            wave_y(1,2,j) = a2*zz
            wave_y(mu,2,j) = a2
            wave_y(mv,2,j) = 0.d0
            s(2,j) = cc
            do m = 1,meqn
                bmdq(m,j) = s(1,j)*wave_y(m,1,j)
                bpdq(m,j) = s(2,j)*wave_y(m,2,j)
                gm(m,i,j) = gm(m,i,j) + bmdq(m,j)
                gp(m,i,j) = gp(m,i,j) - bpdq(m,j)
            enddo
            do mw=1,mwaves
                cflgrid = dmax1(cflgrid, dtdy1d(j)*s(mw,j),-dtdy1d(j-1)*s(mw,j))
            enddo
        enddo
!     -----------------------------------------------------------
!     # modify G fluxes for second order q_{yy} correction terms:
!     -----------------------------------------------------------
        if (method(2).ne.1) then ! if second-order
            ! # apply limiter to waves:
            if (limit) then ! limiter if
                wave_y_tmp = wave_y
                do mw=1,mwaves ! mwaves loop
                    do j = 1, my+1 ! my loop
                        if (mthlim(mw) .eq. 0) cycle
                        dot = 0.d0
                        wnorm2 = 0.d0
                        do m=1,meqn
                            wnorm2 = wnorm2 + wave_y_tmp(m,mw,j)**2
                        enddo
                        if (wnorm2.eq.0.d0) cycle

                        if (s(mw,j) .gt. 0.d0) then
                            do m=1,meqn
                                dot = dot + wave_y_tmp(m,mw,j)*wave_y_tmp(m,mw,j-1)
                            enddo
                        else
                            do m=1,meqn
                                dot = dot + wave_y_tmp(m,mw,j)*wave_y_tmp(m,mw,j+1)
                            enddo
                        endif

                        r = dot / wnorm2

                        ! choose limiter
                        if (mthlim(mw) .eq. 1) then
                            !               --------
                            !               # minmod
                            !               --------
                            wlimitr = dmax1(0.d0, dmin1(1.d0, r))

                        else if (mthlim(mw) .eq. 2) then
                            !               ----------
                            !               # superbee
                            !               ----------
                            wlimitr = dmax1(0.d0, dmin1(1.d0, 2.d0*r), dmin1(2.d0, r))

                        else if (mthlim(mw) .eq. 3) then
                            !               ----------
                            !               # van Leer
                            !               ----------
                            wlimitr = (r + dabs(r)) / (1.d0 + dabs(r))

                        else if (mthlim(mw) .eq. 4) then
                            !               ------------------------------
                            !               # monotinized centered
                            !               ------------------------------
                            c = (1.d0 + r)/2.d0
                            wlimitr = dmax1(0.d0, dmin1(c, 2.d0, 2.d0*r))
                        else if (mthlim(mw) .eq. 5) then
                            !               ------------------------------
                            !               # Beam-Warming
                            !               ------------------------------
                            wlimitr = r
                        else
                            print *, 'Unrecognized limiter.'
                            stop
                        endif
                        !
                        !  # apply limiter to waves:
                        !
                        do m=1,meqn
                            wave_y(m,mw,j) = wlimitr * wave_y(m,mw,j)
                        enddo
                    enddo ! end my loop
                enddo ! end mwave loop
            endif ! end limiter if
            do j = 1, my+1 ! my loop
                !        # For correction terms below, need average of dtdx in cell
                !        # j-1 and j.  Compute these and overwrite dtdx1d:
                !
                !        # modified in Version 4.3 to use average only in cqyy, not transverse
                dtdyave = 0.5d0 * (dtdy1d(j-1) + dtdy1d(j))
                !        # second order corrections:
                do m=1,meqn
                    cqyy(m,j) = 0.d0
                    do mw=1,mwaves
                        if (use_fwaves) then
                            abs_sign = dsign(1.d0,s(mw,j))
                        else
                            abs_sign = dabs(s(mw,j))
                        endif

                        cqyy(m,j) = cqyy(m,j) + abs_sign * &
                            (1.d0 - dabs(s(mw,j))*dtdyave) * wave_y(m,mw,j)
                    enddo
                    gp(m,i,j) = gp(m,i,j) + 0.5d0 * cqyy(m,j)
                    gm(m,i,j) = gm(m,i,j) + 0.5d0 * cqyy(m,j)
                enddo
            enddo ! end my loop
        endif ! end if second-order 
!     -----------------------------------------------------------
!     # END modify G fluxes for second order q_{yy} correction terms:
!     -----------------------------------------------------------
    enddo


end subroutine step2_fused
