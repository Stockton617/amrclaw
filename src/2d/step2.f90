!> Compute all fluxes at cell edges 
!! \param qold[in] solution array for computing fluxes. It is not changed in this subroutine
!! \param fm[out] fluxes on the left side of each vertical edge
!! \param fp[out] fluxes on the right side of each vertical edge
!! \param gm[out] fluxes on the lower side of each horizontal edge
!! \param gp[out] fluxes on the upper side of each horizontal edge
subroutine step2(maxm,meqn,maux,mbc,mx,my,qold,aux,dx,dy,dt,cflgrid,fm,fp,gm,gp,rpn2,rpt2)
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

    implicit none
    
    external rpn2, rpt2
    
    ! Arguments
    integer, intent(in) :: maxm,meqn,maux,mbc,mx,my
    real(CLAW_REAL), intent(in) :: dx,dy,dt
    real(CLAW_REAL), intent(inout) :: cflgrid
    real(CLAW_REAL), intent(inout) :: qold(meqn, 1-mbc:mx+mbc, 1-mbc:my+mbc)
    real(CLAW_REAL), intent(inout) :: aux(maux,1-mbc:mx+mbc, 1-mbc:my+mbc)
    real(CLAW_REAL), intent(inout) :: fm(meqn, 1-mbc:mx+mbc, 1-mbc:my+mbc)
    real(CLAW_REAL), intent(inout) :: fp(meqn,1-mbc:mx+mbc, 1-mbc:my+mbc)
    real(CLAW_REAL), intent(inout) :: gm(meqn,1-mbc:mx+mbc, 1-mbc:my+mbc)
    real(CLAW_REAL), intent(inout) :: gp(meqn,1-mbc:mx+mbc, 1-mbc:my+mbc)
    
    ! Local storage for flux accumulation
    real(CLAW_REAL) :: faddm(meqn,1-mbc:maxm+mbc)
    real(CLAW_REAL) :: faddp(meqn,1-mbc:maxm+mbc)
    real(CLAW_REAL) :: gaddm(meqn,1-mbc:maxm+mbc,2)
    real(CLAW_REAL) :: gaddp(meqn,1-mbc:maxm+mbc,2)
    
    ! Scratch storage for Sweeps and Riemann problems
    real(CLAW_REAL) ::  q1d(meqn,1-mbc:maxm+mbc)
    real(CLAW_REAL) :: aux1(maux,1-mbc:maxm+mbc)
    real(CLAW_REAL) :: aux2(maux,1-mbc:maxm+mbc)
    real(CLAW_REAL) :: aux3(maux,1-mbc:maxm+mbc)
    real(CLAW_REAL) :: dtdx1d(1-mbc:maxm+mbc)
    real(CLAW_REAL) :: dtdy1d(1-mbc:maxm+mbc)
    
    real(CLAW_REAL) ::  wave(meqn, mwaves, 1-mbc:maxm+mbc)
    real(CLAW_REAL) ::     s(mwaves, 1-mbc:maxm + mbc)
    real(CLAW_REAL) ::  amdq(meqn,1-mbc:maxm + mbc)
    real(CLAW_REAL) ::  apdq(meqn,1-mbc:maxm + mbc)
    real(CLAW_REAL) ::  cqxx(meqn,1-mbc:maxm + mbc)
    real(CLAW_REAL) :: bmadq(meqn,1-mbc:maxm + mbc)
    real(CLAW_REAL) :: bpadq(meqn,1-mbc:maxm + mbc)
    
    ! Looping scalar storage
    integer :: i,j,thread_num
    real(CLAW_REAL) :: dtdx,dtdy,cfl1d
    
    
    cflgrid = 0.d0
    dtdx = dt/dx
    dtdy = dt/dy
    
    fm = 0.d0
    fp = 0.d0
    gm = 0.d0
    gp = 0.d0
    
    ! ============================================================================
    ! Perform X-Sweeps
    do j = 0,my+1
        ! Copy old q into 1d slice
        q1d(:,1-mbc:mx+mbc) = qold(:,1-mbc:mx+mbc,j)
        
        ! Set dtdx slice if a capacity array exists
        if (mcapa > 0)  then
            dtdx1d(1-mbc:mx+mbc) = dtdx / aux(mcapa,1-mbc:mx+mbc,j)
        else
            dtdx1d = dtdx
        endif
        
        ! Copy aux array into slices
        if (maux > 0) then
            aux1(:,1-mbc:mx+mbc) = aux(:,1-mbc:mx+mbc,j-1)
            aux2(:,1-mbc:mx+mbc) = aux(:,1-mbc:mx+mbc,j  )
            aux3(:,1-mbc:mx+mbc) = aux(:,1-mbc:mx+mbc,j+1)
        endif
        

        ! Compute modifications fadd and gadd to fluxes along this slice:
        call flux2(1,maxm,meqn,maux,mbc,mx,q1d,dtdx1d,aux1,aux2,aux3, &
                   faddm,faddp,gaddm,gaddp,cfl1d,wave,s, &
                   amdq,apdq,cqxx,bmadq,bpadq,rpn2,rpt2)       
                   
        cflgrid = max(cflgrid,cfl1d)

        ! Update fluxes
        ! here gm(:,i,j) and gp(:,i,j) are the same since
        ! they are both \tilde{G}_{i-1/2,j} in the textbook
        fm(:,1:mx+1,j) = fm(:,1:mx+1,j) + faddm(:,1:mx+1)
        fp(:,1:mx+1,j) = fp(:,1:mx+1,j) + faddp(:,1:mx+1)
        gm(:,1:mx+1,j) = gm(:,1:mx+1,j) + gaddm(:,1:mx+1,1)
        gp(:,1:mx+1,j) = gp(:,1:mx+1,j) + gaddp(:,1:mx+1,1)
        gm(:,1:mx+1,j+1) = gm(:,1:mx+1,j+1) + gaddm(:,1:mx+1,2)
        gp(:,1:mx+1,j+1) = gp(:,1:mx+1,j+1) + gaddp(:,1:mx+1,2)
        
    enddo

    ! ============================================================================
    !  y-sweeps    
    !
    do i = 0,mx+1
        
        ! Copy data along a slice into 1d arrays:
        q1d(:,1-mbc:my+mbc) = qold(:,i,1-mbc:my+mbc)

        ! Set dt/dy ratio in slice
        if (mcapa > 0) then
            dtdy1d(1-mbc:my+mbc) = dtdy / aux(mcapa,i,1-mbc:my+mbc)
        else
            dtdy1d = dtdy
        endif

        ! Copy aux slices
        if (maux .gt. 0)  then
            aux1(:,1-mbc:my+mbc) = aux(:,i-1,1-mbc:my+mbc)
            aux2(:,1-mbc:my+mbc) = aux(:,i,1-mbc:my+mbc)
            aux3(:,1-mbc:my+mbc) = aux(:,i+1,1-mbc:my+mbc)
        endif
        
        
        ! Compute modifications fadd and gadd to fluxes along this slice
        call flux2(2,maxm,meqn,maux,mbc,my,q1d,dtdy1d,aux1,aux2,aux3, &
                   faddm,faddp,gaddm,gaddp,cfl1d,wave,s,amdq,apdq,cqxx, &
                   bmadq,bpadq,rpn2,rpt2)

        cflgrid = max(cflgrid,cfl1d)

        ! Update fluxes
        gm(:,i,1:my+1) = gm(:,i,1:my+1) + faddm(:,1:my+1)
        gp(:,i,1:my+1) = gp(:,i,1:my+1) + faddp(:,1:my+1)
        fm(:,i,1:my+1) = fm(:,i,1:my+1) + gaddm(:,1:my+1,1)
        fp(:,i,1:my+1) = fp(:,i,1:my+1) + gaddp(:,1:my+1,1)
        fm(:,i+1,1:my+1) = fm(:,i+1,1:my+1) + gaddm(:,1:my+1,2)
        fp(:,i+1,1:my+1) = fp(:,i+1,1:my+1) + gaddp(:,1:my+1,2)

    enddo


end subroutine step2
