      program upscale3d
! -------------------------------------------------------------------- !
!     This program reads in 3D fields of scalar or tensor variables 
!     defined on a cartesian grid and upscales or downscales them as
!     needed to generate values for a different cartesian grid. Volume 
!     averaging is used for upscaling volumetric properties such as
!     porosity. The principal components of upscaled permeability 
!     tensors are computed as the geometric mean of the so-called 
!     Cardwell and Parsons (1945) bounds (see refs. below) for each of
!     the three principal directions. Downscaling is done by sampling. 
!     The only restriction is that the gridded output domain lies 
!     within the domain defined by the input grid.
! 
!     References:
!
!     Cardwell WT and RL Parsons. 1945. Average Permeabilities of
!     Heterogeneous Oil Sands. Trans. AIME 160:34-42.
!
!     Malik MA and LW Lake. 1997. A Practical Approach to Scaling-Up
!     Permeability and Relative Pemeabilities in Heterogeneous 
!     Permeable Media. paper SPE 38310, presented at the 1997 SPE 
!     Western Regional Meeting, Long Beach, California, 25-27 June.
!
!     Li D., B Beckner, and A Kumar. 2001. A New Efficient Averaging
!     Technique for Scaleup of Multimillion-Cell Geologic Models.
!     paper SPE 72599, SPE Reservoir Evaluation & Engineering,
!     8:297-307.
!
!     Written by ML Rockhold, PNNL, July 29, 2004.
!     Modified by MLR, March 23, 2005, to write fine grid and upscaled
!       property fields out in Tecplot cell-centered block format.
!     Modified by MLR, July 8, 2005, to use allocatable memory.
!     Modified by MLR, May 25, 2010, to specify scalar or tensor
!       variables, and core-scale anisotropy factor (kx/kz) for  
!       tensor variables, in the filelist file. Memory allocation
!       was also modified. 
!     Modified by MLR, May 21, 2012, to upscale indicator fields.
!     Note: for indicator fields, the integer value in the filelist
!     file is the number of indicator classes.
!     Modified by MLR, 12-Feb-2015, to write out cell face coords
!     for original and upscaled model grids.
! -------------------------------------------------------------------- !
      implicit real*8 (a-h,o-z)
      implicit integer*4 (i-n)

      integer, parameter :: dp=selected_real_kind(14)
      integer, parameter :: sp=selected_real_kind(6)

!gslib grid: grid.gslib
      parameter( nnxf=148, nnyf=160, nnzf=340 )           ! input grid 
!stomp grid: grid.stomp, grid.stompmod
      parameter( nnxc=89, nnyc=93, nnzc=330 )           ! output grid full domain
!refined temporary grid: grid.downscale
!      parameter( nnxc=121, nnyc=133, nnzc=116 )           ! output grid full domain
      parameter( nfiles= 1 )

      parameter( nntf=nnxf*nnyf*nnzf, nntc=nnxc*nnyc*nnzc )  
      parameter( ncfxf=nnxf+1, ncfyf=nnyf+1, ncfzf=nnzf+1 )
      parameter( ncfxc=nnxc+1, ncfyc=nnyc+1, ncfzc=nnzc+1 )
      parameter( ncftf=ncfxf*ncfyf*ncfzf )
      parameter( ncftc=ncfxc*ncfyc*ncfzc )

!      real(kind=dp), dimension(:,:), allocatable :: vari
!      real(kind=dp), dimension(:,:), allocatable :: varo 
      real(kind=dp), dimension(:), allocatable :: vari
      real(kind=dp), dimension(:), allocatable :: varo 
      real(kind=dp), dimension(:), allocatable :: tmp 
      real(kind=dp), dimension(:), allocatable :: tmpx
      real(kind=dp), dimension(:), allocatable :: tmpy
      real(kind=dp), dimension(:), allocatable :: tmpz
      real(kind=dp), dimension(:), allocatable :: anix 
      real(kind=dp), dimension(:), allocatable :: aniy 

      real(kind=dp), dimension(:), allocatable :: cfxf 
      real(kind=dp), dimension(:), allocatable :: cfyf 
      real(kind=dp), dimension(:), allocatable :: cfzf 
      real(kind=dp), dimension(:), allocatable :: cfxc 
      real(kind=dp), dimension(:), allocatable :: cfyc 
      real(kind=dp), dimension(:), allocatable :: cfzc 

      real(kind=dp), dimension(:), allocatable :: xpc 
      real(kind=dp), dimension(:), allocatable :: ypc 
      real(kind=dp), dimension(:), allocatable :: zpc 
      real(kind=dp), dimension(:), allocatable :: xpf 
      real(kind=dp), dimension(:), allocatable :: ypf 
      real(kind=dp), dimension(:), allocatable :: zpf 

      real(kind=dp), dimension(:), allocatable :: cfxcg 
      real(kind=dp), dimension(:), allocatable :: cfycg 
      real(kind=dp), dimension(:), allocatable :: cfzcg 
      real(kind=dp), dimension(:), allocatable :: cfxfg 
      real(kind=dp), dimension(:), allocatable :: cfyfg 
      real(kind=dp), dimension(:), allocatable :: cfzfg 

      integer, dimension(:), allocatable :: ixs
      integer, dimension(:), allocatable :: iys
      integer, dimension(:), allocatable :: izs
      integer, dimension(:), allocatable :: ixe
      integer, dimension(:), allocatable :: iye
      integer, dimension(:), allocatable :: ize

      integer, dimension(:), allocatable :: itmp
      integer, dimension(:), allocatable :: itmpx

      integer, dimension(:), allocatable :: iparamf
      integer, dimension(:), allocatable :: iparamc

      character(33), dimension(:), allocatable :: fname1
      character(33), dimension(:), allocatable :: fname2
      character(33), dimension(:), allocatable :: fname3
      character(80) :: header
      character(33) :: io1,io2,io3
      character(1) :: ans, tens

      allocate ( cfxf(1:ncfxf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating cfxf array'
      allocate ( cfyf(1:ncfyf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating cfyf array'
      allocate ( cfzf(1:ncfzf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating cfzf array'
      allocate ( cfxc(1:ncfxc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating cfxc array'
      allocate ( cfyc(1:ncfyc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating cfyc array'
      allocate ( cfzc(1:ncfzc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating cfzc array'

      allocate ( xpc(1:nnxc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating xpc array'
      allocate ( ypc(1:nnyc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating ypc array'
      allocate ( zpc(1:nnzc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating zpc array'
      allocate ( xpf(1:nnxf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating xpf array'
      allocate ( ypf(1:nnyf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating ypf array'
      allocate ( zpf(1:nnzf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating zpf array'
!      allocate ( anix(1:nnzf), stat=istat )
      allocate ( anix(1:nntf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating anix array'
!      allocate ( aniy(1:nnzf), stat=istat )
      allocate ( aniy(1:nntf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating aniy array'

      allocate ( cfxcg(1:ncftc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating cfxcg array'
      allocate ( cfycg(1:ncftc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating cfycg array'
      allocate ( cfzcg(1:ncftc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating cfzcg array'
      allocate ( cfxfg(1:ncftf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating cfxfg array'
      allocate ( cfyfg(1:ncftf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating cfyfg array'
      allocate ( cfzfg(1:ncftf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating cfzfg array'

      allocate ( ixs(1:nnxc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating ixs array'
      allocate ( iys(1:nnyc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating iys array'
      allocate ( izs(1:nnzc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating izs array'
      allocate ( ixe(1:nnxc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating ixe array'
      allocate ( iye(1:nnyc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating iye array'
      allocate ( ize(1:nnzc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating ize array'

      allocate ( iparamf(1:nntf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating iparamg array'
      allocate ( iparamc(1:nntc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating iparamc array'

      allocate ( fname1(1:nfiles), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating fname1 array'
      allocate ( fname2(1:nfiles), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating fname2 array'
      allocate ( fname3(1:nfiles), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating fname3 array'
!
! --- Define array pointer variables.
!
      nxyf = nnxf*nnyf
      nxyc = nnxc*nnyc
!
! --- Read output grid information. 
!
      write(*,*)' '
      write(*,*)' Enter the name of the output grid file:'
      read(*,'(a)') io1
      open(20,file=io1,status='old')
      call rdgrid(cfxc,cfyc,cfzc,xpc,ypc,zpc,&
                  ifld,jfld,kfld,nnxc,nnyc,nnzc) 
      close(20)
      write(*,*)' coarse grid bounds'
      write(*,*) cfxc(1),cfxc(ncfxc)
      write(*,*) cfyc(1),cfyc(ncfyc)
      write(*,*) cfzc(1),cfzc(ncfzc)
!
!MLR, 02.12.15
      open(1,file='cfxc.dat',status='unknown')
      do i = 1,ncfxc
         write(1,*) cfxc(i)
      end do
      close(1)
      open(1,file='cfyc.dat',status='unknown')
      do i = 1,ncfyc
         write(1,*) cfyc(i)
      end do
      close(1)
      open(1,file='cfzc.dat',status='unknown')
      do i = 1,ncfzc
         write(1,*) cfzc(i)
      end do
      close(1)
!MLR, end

!
! --- Read input grid information. 
!
      write(*,*)' Enter the name of the input grid file:'
      read(*,'(a)') io2
      open(20,file=io2,status='old')
      call rdgrid(cfxf,cfyf,cfzf,xpf,ypf,zpf,&
                  ifld,jfld,kfld,nnxf,nnyf,nnzf) 
      close(20)
      write(*,*)' fine grid bounds'
      write(*,*) cfxf(1),cfxf(ncfxf)
      write(*,*) cfyf(1),cfyf(ncfyf)
      write(*,*) cfzf(1),cfzf(ncfzf)
!
!MLR, 02.12.15
      open(1,file='cfxf.dat',status='unknown')
      do i = 1,ncfxf
         write(1,*) cfxf(i)
      end do
      close(1)
      open(1,file='cfyf.dat',status='unknown')
      do i = 1,ncfyf
         write(1,*) cfyf(i)
      end do
      close(1)
      open(1,file='cfzf.dat',status='unknown')
      do i = 1,ncfzf
         write(1,*) cfzf(i)
      end do
      close(1)
!MLR, end

!
! --- Get pointers.
!
      call get_ptr( cfxf,cfyf,cfzf,cfxc,cfyc,cfzc,nnxf,nnyf,nnzf,&
                    nnxc,nnyc,nnzc,ixs,ixe,iys,iye,izs,ize )
!
! --- Prompt for Tecplot file with input grid values.
!
      write(*,*)' Write out a Tecplot file for the input grid? (y or n)'
      read(*,'(a)') ans
!
! --- Read the property fields defined for the input grid. 
!
      write(*,*)' Enter file containing list of property field files'
      read(*,'(a)') io3
      write(*,*)' filename:',io3
      open(1,file=io3,status='old')
      read(1,*) numfiles
      write(*,*) numfiles,' property field files to read.'
!
!      allocate ( vari(1:nntf,1:numfiles), stat=istat )
!      if( istat.ne.0 ) write(*,*)' error allocating vari array'
!
      allocate ( tmp(1:nntf), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating tmp array'
      allocate ( tmpx(1:nntc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating tmpx array'
      allocate ( tmpy(1:nntc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating tmpy array'
      allocate ( tmpz(1:nntc), stat=istat )
      if( istat.ne.0 ) write(*,*)' error allocating tmpz array'

      itcnt = numfiles 
      do i = 1,numfiles
        read(1,*) fname1(i), tens, anic 
        write(*,*) fname1(i), tens, anic
        if( tens.eq.'t' .or. tens.eq.'T') itcnt = itcnt + 2  
      end do
      rewind(1)
      if( tens.eq.'i' .or. tens.eq.'I' ) then
        allocate ( vari(1:nntf), stat=istat )
        if( istat.ne.0 ) write(*,*)' error allocating vari array'
        allocate ( itmp(1:nntf), stat=istat )
        if( istat.ne.0 ) write(*,*)' error allocating itmp array'
        allocate ( itmpx(1:nntc), stat=istat )
        if( istat.ne.0 ) write(*,*)' error allocating itmpx array'
        write(*,*)' okay allocating itmp and itmpx'
      else
!        allocate ( varo(1:nntc,1:itcnt), stat=istat )
        allocate ( varo(1:nntc), stat=istat )
        if( istat.ne.0 ) write(*,*)' error allocating varo array'
        write(*,*)' okay allocating varo'
      endif

      it = 0
      read(1,*) numfiles
      do i = 1,numfiles
        read(1,*) fname1(i), tens, anic 
        write(*,*) fname1(i), tens, anic
        open(2,file=fname1(i),status='old')
!
!        write(*,*)' flipping z for read since data are top to bottom'
!        read(2,*) (vari(n,i),n=nntf,1,-1)
!
!        do j = 1,9
!          read(2,'(a)') header
!        end do
        if( tens.eq.'i' .or. tens.eq.'I') then
          do n = 1,nntf
!            read(2,*) tjnk, tjnk, tjnk, itmp(n)
            read(2,*) itmp(n)
          end do
!        else
!          do n = 1,nntf
!            read(2,*) tmp1, tmp2, tmp3, vari(n,i)
!          end do
        endif
        write(*,*)' finished reading file...'
!        read(2,*) (vari(n,i),n=1,nntf)
!        do k = 1,nntf
!          tmp(k) = vari(k,i)
!          write(*,*) tmp(k)
!        end do
        close(2)
        if( tens.eq.'t' .or. tens.eq.'T') then  
          it = it + 2
          do k = 1,nntf
            anix(k) = anic 
            aniy(k) = anic 
          end do
          write(*,*)' upscaling tensor variable' 
          call upscale_t(tmp,anix,aniy,tmpx,tmpy,tmpz,cfxf,cfyf,cfzf,&
               cfxc,cfyc,cfzc,ixs,ixe,iys,iye,izs,ize,nntf,nntc,nnxf,&
               nnyf,nnzf,nnxc,nnyc,nnzc,ncfxf,ncfyf,ncfzf,ncfxc,&
               ncfyc,ncfzc)
          write(*,*)' returned from upscale_t'
          do k = 1,nntc
!            varo(k,i) = tmpx(k)
!            varo(k,numfiles+it-1) = tmpy(k)
!            varo(k,numfiles+it) = tmpz(k)
            varo(k) = tmpx(k)
            varo(k) = tmpy(k)
            varo(k) = tmpz(k)
          end do
        elseif( tens.eq.'s' .or. tens.eq.'S') then
          write(*,*)' upscaling scalar variable'
          call upscale_s(tmp,tmpx,cfxf,cfyf,cfzf,cfxc,cfyc,cfzc,&
                     ixs,ixe,iys,iye,izs,ize,nntf,nntc,nnxf,nnyf,nnzf,&
                     nnxc,nnyc,nnzc,ncfxf,ncfyf,ncfzf,ncfxc,ncfyc,ncfzc)
!          write(*,*)' returned from upscale_s'
          do k = 1,nntc
!            varo(k,i) = tmpx(k)
            varo(k) = tmpx(k)
          end do
!NEW! 05.21.12
        elseif( tens.eq.'i' .or. tens.eq.'I' ) then
! looks like anic or mf is the number of facies categories
! when using indicator variables.
          mf = nint(anic)
          write(*,*)' upscaling indicator (integer) field'
          call upscale_i(mf,itmp,itmpx,cfxf,cfyf,cfzf,cfxc,cfyc,cfzc,&
                     ixs,ixe,iys,iye,izs,ize,nntf,nntc,nnxf,nnyf,nnzf,&
                     nnxc,nnyc,nnzc,ncfxf,ncfyf,ncfzf,ncfxc,ncfyc,ncfzc)
        endif
      end do
      rewind(1)
  465 format(6(1x,1pe12.4))
  466 format(1x,i3)
!
! --- Load output grid global cell faces array.
!
      ntot1 = 0 
      do k = 1,ncfzc
        do j = 1,ncfyc
          do i = 1,ncfxc
            ntot1 = ntot1 + 1
            cfxcg(ntot1) = cfxc(i)
            cfycg(ntot1) = cfyc(j)
            cfzcg(ntot1) = cfzc(k)
          end do
        end do
      end do
!
! --- Write out upscaled property fields for plotting with Tecplot.
!
      write(*,*)' '
      write(*,*)' Writing upscaled results to Tecplot file.'
      write(*,*)'( NOTE: Tecplot coords are output in units of m !! )'
      write(*,*)' '
      open(21,file='grid-out.tec',status='unknown')
      write(21,*)'TITLE="Output Grid (Upscaled) Property Fields" '
      write(21,*)'VARIABLES=" X (m)"'
      write(21,*)'" Y (m)" '
      write(21,*)'" Z (m)" '
      do i = 1,itcnt
        write(21,*)'"var',i,'"'
      end do
!
! --- Tecplot cell-centered block format.
!
      write(21,*)'ZONE F=BLOCK ','I=',ncfxc,',J=',ncfyc,',K=',ncfzc
!      write(21,*)' VARLOCATION=([4-',4+itcnt,']=CELLCENTERED)'
      write(21,*)' VARLOCATION=([4]=CELLCENTERED)'
      write(21,574) (cfxcg(i),i=1,ntot1)
      write(21,574) (cfycg(i),i=1,ntot1)
      write(21,574) (cfzcg(i),i=1,ntot1)
      if( tens.eq.'i' .or. tens.eq.'I' ) then
        write(21,575) (itmpx(k),k=1,nntc)
      else 
        do i = 1,itcnt
!          write(21,574) (varo(k,i),k=1,nntc)
          write(21,574) (varo(k),k=1,nntc)
        end do
      endif
      close(21)

      if( ans.eq.'y' ) then
        ntot2 = 0 
        do k = 1,ncfzf
          do j = 1,ncfyf
            do i = 1,ncfxf
              ntot2 = ntot2 + 1
              cfxfg(ntot2) = cfxf(i)
              cfyfg(ntot2) = cfyf(j)
              cfzfg(ntot2) = cfzf(k)
            end do
          end do
        end do

        write(*,*)' writing fine grid results to Tecplot file'
        write(*,*)'(NOTE: Tecplot coords are output in units of m!!)'
        write(*,*)' '
        open(21,file='grid-in.tec',status='unknown')
        write(21,*)'TITLE="Input Grid Property Fields"'
        write(21,*)'VARIABLES=" X (m)"'
        write(21,*)'" Y (m)" '
        write(21,*)'" Z (m)" '
        do i = 1,numfiles
          write(21,*)'"var',i,'"'
        end do
!
! --- Tecplot cell-centered block format.
!
      write(21,*)'ZONE F=BLOCK ','I=',ncfxf,',J=',ncfyf,',K=',ncfzf
!      write(21,*)' VARLOCATION=([4-',4+numfiles,']=CELLCENTERED)'
      write(21,*)' VARLOCATION=([4]=CELLCENTERED)'
      write(21,574) (cfxfg(i),i=1,ntot2)
      write(21,574) (cfyfg(i),i=1,ntot2)
      write(21,574) (cfzfg(i),i=1,ntot2)
      if( tens.eq.'i' .or. tens.eq.'I' ) then
        write(21,575) (itmp(k),k=1,nntf)
      else
         do i = 1,numfiles
!           write(21,574) (vari(k,i),k=1,nntf)
           write(21,574) (vari(k),k=1,nntf)
         end do
      endif
      close(21)

      endif
  574 format(5(1x,1pe13.6))
  575 format(4(1x,i3))
!
! --- Write out upscaled property fields for reading into STOMP. 
!
      write(*,*)' writing out upscaled property fields for STOMP'
      it = 0
      read(1,*) numfiles
      do i = 1,numfiles
        read(1,*) fname1(i),tens,anic
!        do j = 1,10
        do j = 1,33
          if( fname1(i)(j:j).eq.'.') then
            write(fname2(i)(1:j-1),'(a)') fname1(i)(1:j-1)
            write(fname3(i)(1:j-1),'(a)') fname1(i)(1:j-1)
            if( tens.eq.'t'.or.tens.eq.'T' ) then
              it = it + 2
              fname2(i)(j:j+4) ='.upsx'
            else
              fname2(i)(j:j+3) ='.ups'
!              fname3(i)(j:j+3) ='.fac'
            endif
            goto 220
          endif
        end do
  220   continue
!
! This is the upscaled zonation file.
        open(2,file=fname2(i),status='unknown')
        if( tens.eq.'i'.or.tens.eq.'I' ) then
          write(2,466) (itmpx(k),k=1,nntc)
!
          fname3(i)(j:j+4) ='.facx'
          open(3,file=fname3(i),status='unknown')
          write(3,101) (cfxc(n),n=1,ncfxc)
          close(3)
          fname3(i)(j:j+4) ='.facy'
          open(3,file=fname3(i),status='unknown')
          write(3,101) (cfyc(n),n=1,ncfyc) 
          close(3)
          fname3(i)(j:j+4) ='.facz'
          open(3,file=fname3(i),status='unknown')
          write(3,101) (cfzc(n),n=1,ncfzc) 
          close(3)
! MLR, 01.07.12.
! Write out base boundary cell coords to be used by BC script
          fname3(i)(j:j+4) ='.bnd '
          open(3,file=fname3(i),status='unknown')
          do ii = 1,nnxc
            write(3,102) ii,xpc(ii),cfyc(ncfyc)
          end do
          do ii = 1,nnxc
            write(3,103) ii,xpc(ii),cfyc(1)
          end do
          do jj = 1,nnyc
!            write(3,104) jj,ypc(jj),cfxc(1) 
            write(3,104) jj,cfxc(1),ypc(jj) 
          end do 
          close(3)
  102     format('north,',i4,',',f12.4,',',f12.4)
  103     format('south,',i4,',',f12.4,',',f12.4)
  104     format('west,',i4,',',f12.4,',',f12.4)
        else
!          write(2,465) (varo(k,i),k=1,nntc)
          write(2,465) (varo(k),k=1,nntc)
        endif
        close(2) 
        if( tens.eq.'t'.or.tens.eq.'T') then
          fname2(i)(j:j+4) ='.upsy'
          open(2,file=fname2(i),status='unknown')
!          write(2,465) (varo(k,numfiles+it-1),k=1,nntc)
          write(2,465) (varo(k),k=1,nntc)
          close(2) 
          fname2(i)(j:j+4) ='.upsz'
          open(2,file=fname2(i),status='unknown')
!          write(2,465) (varo(k,numfiles+it),k=1,nntc)
          write(2,465) (varo(k),k=1,nntc)
          close(2) 
        endif
      end do
      close(1)
      write(*,*)' fini ! '
  100 format(1pe12.4)
  101 format(f12.4)
      stop
      end


      subroutine upscale_t(skf,anix,aniy,xk,yk,zk,cfxf,cfyf,cfzf,&
                           cfxc,cfyc,cfzc,ixs,ixe,iys,iye,izs,ize,&
                           nntf,nntc,nnxf,nnyf,nnzf,nnxc,nnyc,nnzc,&
                           ncfxf,ncfyf,ncfzf,ncfxc,ncfyc,ncfzc)
! -------------------------------------------------------------------- !
!     Reads 3-D hydraulic conductivity distribution generated on a fine 
!     grid with cartesian coordinates and computes upscaled hydraulic 
!     conductivities for each grid block in a coarser model grid. The 
!     components of the upscaled K tensors are computed from weighted 
!     arithmetic or harmonic averages of the fine grid block K values,
!     parallel and perpendicular to the direction of flow, respectively, 
!     to get the so-called Cardwell and Parsons (CP) bounds. The 
!     effective values of the K tensor are then calculated as the 
!     geometric mean of the CP bounds. This scheme yields the exact, 
!     analytical results for cases of perfect horizontal or vertical 
!     stratification (weighted arithmetic or harmonic means), or for 
!     2D, statistically homogeneous, isotropic media (geometric mean). 
!
!     Note: This is a general algorithm that works with both uniform 
!       or nonuniform grids. The only restriction is that all grid 
!       blocks in the second (usually coarser) grid must lie within 
!       the domain of the first (usually finer) grid.
!
!     Written by ML Rockhold, PNNL, July 1, 1997. 
!     Last modified by ML Rockhold, Nov 23, 2004. 
! -------------------------------------------------------------------- !
      implicit real*8 (a-h,o-z)
      dimension skf(nntf), anix(nntf), aniy(nntf),&
                xk(nntc), yk(nntc), zk(nntc)
      dimension cfxf(ncfxf), cfyf(ncfyf), cfzf(ncfzf),&
                cfxc(ncfxc), cfyc(ncfyc), cfzc(ncfzc) 
      dimension ixs(nnxc), ixe(nnxc), iys(nnyc), iye(nnyc),&
                izs(nnzc), ize(nnzc)

      nxyf = nnxf*nnyf
      nxyc = nnxc*nnyc
!
! --- Loop over the coarse grid blocks, aggregate data from the 
!     fine grid blocks, and determine the components of upscaled 
!     hydraulic conductivity tensors.
!
      do k = 1,nnzc
        do j = 1,nnyc
          do i = 1,nnxc
            nc = i + (j-1)*nnxc + (k-1)*nxyc
            xk(nc) = 0.d0
            yk(nc) = 0.d0
            zk(nc) = 0.d0            
!
! --- compute lower CP bound for Kx component
!
            sumxk = 0.d0
            sumdydz = 0.d0
            do kk = izs(k),ize(k)
              if( cfzf(kk).lt.cfzc(k) ) then
                dz = cfzf(kk+1) - cfzc(k)
                if( cfzc(k+1).le.cfzf(kk+1) ) dz = cfzc(k+1) - cfzc(k)
              elseif( cfzf(kk+1).gt.cfzc(k+1) ) then
                dz = cfzc(k+1) - cfzf(kk)
              else
                dz = cfzf(kk+1) - cfzf(kk)
              endif
              do jj = iys(j),iye(j)
                if( cfyf(jj).lt.cfyc(j) ) then
                  dy = cfyf(jj+1) - cfyc(j)
                  if( cfyc(j+1).le.cfyf(jj+1) ) dy = cfyc(j+1) - cfyc(j)
                elseif( cfyf(jj+1).gt.cfyc(j+1) ) then
                  dy = cfyc(j+1) - cfyf(jj)
                else
                  dy = cfyf(jj+1) - cfyf(jj)
                endif
                dydz = dy*dz
                sumdydz = sumdydz + dydz
                sumdx = 0.d0
                sumdxk = 0.d0
                do ii = ixs(i),ixe(i)
                  if( cfxf(ii).lt.cfxc(i) ) then
                    dx = cfxf(ii+1) - cfxc(i)
                    if( cfxc(i+1).le.cfxf(ii+1) ) dx = cfxc(i+1)-cfxc(i)
                  elseif( cfxf(ii+1) .gt. cfxc(i+1) ) then
                    dx = cfxc(i+1) - cfxf(ii)
                  else
                    dx = cfxf(ii+1) - cfxf(ii)
                  endif
                  nf = ii + (jj-1)*nnxf + (kk-1)*nxyf
                  sumdx = sumdx + dx
                  sumdxk = sumdxk + dx/(anix(nf)*skf(nf))
                end do
                xktmp = (sumdx/sumdxk)*dydz
                sumxk = sumxk + xktmp
              end do
            end do
            xklo = sumxk/sumdydz
!
! --- compute upper CP bound for Kx component
!
            sumxk = 0.d0
            sumdx = 0.d0
            do ii = ixs(i),ixe(i)
              if( cfxf(ii).lt.cfxc(i) ) then
                dx = cfxf(ii+1) - cfxc(i)
                if( cfxc(i+1).le.cfxf(ii+1) ) dx = cfxc(i+1) - cfxc(i)
              elseif( cfxf(ii+1).gt.cfxc(i+1) ) then
                dx = cfxc(i+1) - cfxf(ii)
              else
                dx = cfxf(ii+1) - cfxf(ii)
              endif
              sumdx = sumdx + dx
              sumdxk = 0.d0
              sumdydz = 0.d0
              do kk = izs(k),ize(k)
                if( cfzf(kk).lt.cfzc(k) ) then
                  dz = cfzf(kk+1) - cfzc(k)
                  if( cfzc(k+1).le.cfzf(kk+1) ) dz = cfzc(k+1) - cfzc(k)
                elseif( cfzf(kk+1).gt.cfzc(k+1) ) then
                  dz = cfzc(k+1) - cfzf(kk)
                else
                  dz = cfzf(kk+1) - cfzf(kk)
                endif
                do jj = iys(j),iye(j)
                  if( cfyf(jj).lt.cfyc(j) ) then
                    dy = cfyf(jj+1) - cfyc(j)
                    if( cfyc(j+1).le.cfyf(jj+1) ) dy = cfyc(j+1)-cfyc(j)
                  elseif( cfyf(jj+1) .gt. cfyc(j+1) ) then
                    dy = cfyc(j+1) - cfyf(jj)
                  else
                    dy = cfyf(jj+1) - cfyf(jj)
                  endif
                  dydz = dy*dz
                  sumdydz = sumdydz + dydz
                  nf = ii + (jj-1)*nnxf + (kk-1)*nxyf
                  sumdxk = sumdxk + dydz*(anix(nf)*skf(nf))
                end do
              end do
              xktmp = sumdxk/sumdydz
              sumxk = sumxk + dx/xktmp
            end do
            xkup = sumdx/sumxk
!
! --- compute geometric mean of upper and lower CP bounds for Kx
! 
            xk(nc) = dsqrt( xklo * xkup )
!
! --- compute lower CP bound for Ky component
!
            sumyk = 0.d0
            sumdxdz = 0.d0
            do kk = izs(k),ize(k)
              if( cfzf(kk).lt.cfzc(k) ) then
                dz = cfzf(kk+1) - cfzc(k)
                if( cfzc(k+1).le.cfzf(kk+1) ) dz = cfzc(k+1) - cfzc(k)
              elseif( cfzf(kk+1) .gt. cfzc(k+1) ) then
                dz = cfzc(k+1) - cfzf(kk)
              else
                dz = cfzf(kk+1) - cfzf(kk)
              endif
              do ii = ixs(i),ixe(i)
                if( cfxf(ii).lt.cfxc(i) ) then
                  dx = cfxf(ii+1) - cfxc(i)
                  if( cfxc(i+1).le.cfxf(ii+1) ) dx = cfxc(i+1) - cfxc(i)
                elseif( cfxf(ii+1) .gt. cfxc(i+1) ) then
                  dx = cfxc(i+1) - cfxf(ii)
                else
                  dx = cfxf(ii+1) - cfxf(ii)
                endif
                dxdz = dx*dz
                sumdxdz = sumdxdz + dxdz
                sumdy = 0.d0
                sumdyk = 0.d0
                do jj = iys(j),iye(j)
                  if( cfyf(jj).lt.cfyc(j) ) then
                    dy = cfyf(jj+1) - cfyc(j)
                    if( cfyc(j+1).le.cfyf(jj+1) ) dy = cfyc(j+1)-cfyc(j)
                  elseif( cfyf(jj+1).gt.cfyc(j+1) ) then
                    dy = cfyc(j+1) - cfyf(jj)
                  else
                    dy = cfyf(jj+1) - cfyf(jj)
                  endif
                  nf = ii + (jj-1)*nnxf + (kk-1)*nxyf
                  sumdy = sumdy + dy
                  sumdyk = sumdyk + dy/(aniy(nf)*skf(nf))
                end do
                yktmp = (sumdy/sumdyk)*dxdz
                sumyk = sumyk + yktmp
              end do
            end do
            yklo = sumyk/sumdxdz
!
! --- compute upper CP bound for Ky component
!
            sumyk = 0.d0
            sumdy = 0.d0
            do jj = iys(j),iye(j)
              if( cfyf(jj).lt.cfyc(j) ) then
                dy = cfyf(jj+1) - cfyc(j)
                if( cfyc(j+1).le.cfyf(jj+1) ) dy = cfyc(j+1) - cfyc(j)
              elseif( cfyf(jj+1).gt.cfyc(j+1) ) then
                dy = cfyc(j+1) - cfyf(jj)
              else
                dy = cfyf(jj+1) - cfyf(jj)
              endif
              sumdy = sumdy + dy
              sumdyk = 0.d0
              sumdxdz = 0.d0
              do kk = izs(k),ize(k)
                if( cfzf(kk).lt.cfzc(k) ) then
                  dz = cfzf(kk+1) - cfzc(k)
                  if( cfzc(k+1).le.cfzf(kk+1) ) dz = cfzc(k+1) - cfzc(k)
                elseif( cfzf(kk+1).gt.cfzc(k+1) ) then
                  dz = cfzc(k+1) - cfzf(kk)
                else
                  dz = cfzf(kk+1) - cfzf(kk)
                endif
                do ii = ixs(i),ixe(i)
                  if( cfxf(ii).lt.cfxc(i) ) then
                    dx = cfxf(ii+1) - cfxc(i)
                    if( cfxc(i+1).le.cfxf(ii+1) ) dx = cfxc(i+1)-cfxc(i)
                  elseif( cfxf(ii+1).gt.cfxc(i+1) ) then
                    dx = cfxc(i+1) - cfxf(ii)
                  else
                    dx = cfxf(ii+1) - cfxf(ii)
                  endif
                  dxdz = dx*dz
                  sumdxdz = sumdxdz + dxdz
                  nf = ii + (jj-1)*nnxf + (kk-1)*nxyf
                  sumdyk = sumdyk + dxdz*(aniy(nf)*skf(nf))
                end do
              end do
              yktmp = sumdyk/sumdxdz
              sumyk = sumyk + dy/yktmp
            end do
            ykup = sumdy/sumyk
!
! --- compute geometric mean of upper and lower CP bounds for Ky
!
            yk(nc) = dsqrt( yklo * ykup ) 
!
! --- compute lower CP bound for Kz component
!
            sumzk = 0.d0
            sumdxdy = 0.d0
            do ii = ixs(i),ixe(i)
              if( cfxf(ii).lt.cfxc(i) ) then
                dx = cfxf(ii+1) - cfxc(i)
                if( cfxc(i+1).le.cfxf(ii+1) ) dx = cfxc(i+1) - cfxc(i)
              elseif( cfxf(ii+1).gt.cfxc(i+1) ) then
                dx = cfxc(i+1) - cfxf(ii)
              else
                dx = cfxf(ii+1) - cfxf(ii)
              endif
              do jj = iys(j),iye(j)
                if( cfyf(jj).lt.cfyc(j) ) then
                  dy = cfyf(jj+1) - cfyc(j)
                  if( cfyc(j+1).le.cfyf(jj+1) ) dy = cfyc(j+1) - cfyc(j)
                elseif( cfyf(jj+1).gt.cfyc(j+1) ) then
                  dy = cfyc(j+1) - cfyf(jj)
                else
                  dy = cfyf(jj+1) - cfyf(jj)
                endif
                dxdy = dx*dy
                sumdxdy = sumdxdy + dxdy
                sumdz = 0.d0
                sumdzk = 0.d0
                do kk = izs(k),ize(k)
                  if( cfzf(kk).lt.cfzc(k) ) then
                    dz = cfzf(kk+1) - cfzc(k)
                    if( cfzc(k+1).le.cfzf(kk+1) ) dz = cfzc(k+1)-cfzc(k)
                  elseif( cfzf(kk+1).gt.cfzc(k+1) ) then
                    dz = cfzc(k+1) - cfzf(kk)
                  else
                    dz = cfzf(kk+1) - cfzf(kk)
                  endif
                  nf = ii + (jj-1)*nnxf + (kk-1)*nxyf
                  sumdz = sumdz + dz
                  sumdzk = sumdzk + dz/skf(nf)
                end do
                zktmp = (sumdz/sumdzk)*dxdy
                sumzk = sumzk + zktmp
              end do
            end do
            zklo = sumzk/sumdxdy
!
! --- compute upper CP bound for Kz component
!
            sumzk = 0.d0
            sumdz = 0.d0
            do kk = izs(k),ize(k)
              if( cfzf(kk).lt.cfzc(k) ) then
                dz = cfzf(kk+1) - cfzc(k)
                if( cfzc(k+1).le.cfzf(kk+1) ) dz = cfzc(k+1)-cfzc(k)
              elseif( cfzf(kk+1).gt.cfzc(k+1) ) then
                dz = cfzc(k+1) - cfzf(kk)
              else
                dz = cfzf(kk+1) - cfzf(kk)
              endif
              sumdz = sumdz + dz
              sumdzk = 0.d0
              sumdxdy = 0.d0
              do jj = iys(j),iye(j)
                if( cfyf(jj).lt.cfyc(j) ) then
                  dy = cfyf(jj+1) - cfyc(j)
                  if( cfyc(j+1).le.cfyf(jj+1) ) dy = cfyc(j+1) - cfyc(j)
                elseif( cfyf(jj+1).gt.cfyc(j+1) ) then
                  dy = cfyc(j+1) - cfyf(jj)
                else
                  dy = cfyf(jj+1) - cfyf(jj)
                endif
                do ii = ixs(i),ixe(i)
                  if( cfxf(ii).lt.cfxc(i) ) then
                    dx = cfxf(ii+1) - cfxc(i)
                    if( cfxc(i+1).le.cfxf(ii+1) ) dx = cfxc(i+1)-cfxc(i)
                  elseif( cfxf(ii+1).gt.cfxc(i+1) ) then
                    dx = cfxc(i+1) - cfxf(ii)
                  else
                    dx = cfxf(ii+1) - cfxf(ii)
                  endif
                  dxdy = dx*dy
                  sumdxdy = sumdxdy + dxdy
                  nf = ii + (jj-1)*nnxf + (kk-1)*nxyf
                  sumdzk = sumdzk + dxdy*skf(nf)
                end do
              end do
              zktmp = sumdzk/sumdxdy
              sumzk = sumzk + dz/zktmp
            end do
            zkup = sumdz/sumzk 
!
! --- compute geometric mean of upper and lower CP bounds for Kz
!
            zk(nc) = dsqrt( zklo * zkup )
          end do
        end do
      end do
      return 
      end


      subroutine upscale_s(paramf,paramc,cfxf,cfyf,cfzf,cfxc,cfyc,&
                 cfzc,ixs,ixe,iys,iye,izs,ize,nntf,nntc,nnxf,nnyf,nnzf,&
                 nnxc,nnyc,nnzc,ncfxf,ncfyf,ncfzf,ncfxc,ncfyc,ncfzc)
! -------------------------------------------------------------------- !
!     Upscales a scaler variable assigned on a regular 3D grid with 
!     cartesian coordinates to a different (usually coarser) grid 
!     while maintaining local and global volume and mass balances 
!     between the two domains. (input = paramf, output = paramc)
!
!     Note: This is a general algorithm that works with both
!           uniform or nonuniform grids. The only restriction is 
!           that all grid blocks in the second (coarser) grid must 
!           lie within the domain of the first (finer) grid.
!
!     Written by ML Rockhold, September 6, 1996.
!     Last modified by ML Rockhold, November 23, 2004.
! -------------------------------------------------------------------- !
      implicit real*8 (a-h,o-z)
      dimension paramf(nntf),paramc(nntc)
      dimension cfxf(ncfxf), cfyf(ncfyf), cfzf(ncfzf),&
                cfxc(ncfxc), cfyc(ncfyc), cfzc(ncfzc) 
      dimension ixs(nnxc), ixe(nnxc),&
                iys(nnyc), iye(nnyc),&
                izs(nnzc), ize(nnzc)

      nxyf = nnxf*nnyf
      nxyc = nnxc*nnyc
!
! --- Loop over the coarse grid blocks, aggregate data from 
!     fine grid blocks, and determine volume-weighted, coarse 
!     grid block averages.
!
      do k = 1,nnzc
        do j = 1,nnyc
          do i = 1,nnxc
            nc = i + (j-1)*nnxc + (k-1)*nxyc
            paramc(nc) = 0.d0
            vtot = 0.d0
            do kk = izs(k),ize(k)
              if( cfzf(kk) .lt. cfzc(k) ) then
                dz = cfzf(kk+1) - cfzc(k)
                if( cfzc(k+1).le.cfzf(kk+1) ) dz = cfzc(k+1) - cfzc(k)
              elseif( cfzf(kk+1) .gt. cfzc(k+1) ) then
                dz = cfzc(k+1) - cfzf(kk)
              else
                dz = cfzf(kk+1) - cfzf(kk)
              endif
              do jj = iys(j),iye(j)
                if( cfyf(jj) .lt. cfyc(j) ) then
                  dy = cfyf(jj+1) - cfyc(j)
                  if( cfyc(j+1).le.cfyf(jj+1) ) dy = cfyc(j+1) - cfyc(j)
                elseif( cfyf(jj+1) .gt. cfyc(j+1) ) then
                  dy = cfyc(j+1) - cfyf(jj)
                else
                  dy = cfyf(jj+1) - cfyf(jj)
                endif
                do ii = ixs(i),ixe(i)
                  if( cfxf(ii) .lt. cfxc(i) ) then
                    dx = cfxf(ii+1) - cfxc(i)
                    if( cfxc(i+1).le.cfxf(ii+1) ) dx = cfxc(i+1)-cfxc(i)
                  elseif( cfxf(ii+1) .gt. cfxc(i+1) ) then
                    dx = cfxc(i+1) - cfxf(ii)
                  else
                    dx = cfxf(ii+1) - cfxf(ii)
                  endif
                  vo = dx*dy*dz
                  vtot = vtot + vo
                  nf = ii + (jj-1)*nnxf + (kk-1)*nxyf
                  paramc(nc) = paramc(nc) + paramf(nf)*vo
                end do
              end do
            end do
            paramc(nc) = paramc(nc)/vtot
          end do
        end do
      end do
      return 
      end


      subroutine upscale_i(mf,iparamf,iparamc,cfxf,cfyf,cfzf,cfxc,cfyc,&
                 cfzc,ixs,ixe,iys,iye,izs,ize,nntf,nntc,nnxf,nnyf,nnzf,&
                 nnxc,nnyc,nnzc,ncfxf,ncfyf,ncfzf,ncfxc,ncfyc,ncfzc)
! -------------------------------------------------------------------- !
!     Upscales an indicator variable assigned on a regular 3D grid with 
!     cartesian coordinates to a different (usually coarser) grid 
!     while maintaining local and global volume and mass balances 
!     between the two domains. (input = paramf, output = paramc)
!
!     Note: This is a general algorithm that works with both
!           uniform or nonuniform grids. The only restriction is 
!           that all grid blocks in the second (coarser) grid must 
!           lie within the domain of the first (finer) grid.
!
!     Written by ML Rockhold, September 6, 1996.
!     Last modified by ML Rockhold, November 23, 2004.
! -------------------------------------------------------------------- !
      implicit real*8 (a-h,o-z)
      dimension iparamf(nntf),iparamc(nntc)
      dimension cfxf(ncfxf), cfyf(ncfyf), cfzf(ncfzf),&
                cfxc(ncfxc), cfyc(ncfyc), cfzc(ncfzc) 
      dimension ixs(nnxc), ixe(nnxc),&
                iys(nnyc), iye(nnyc),&
                izs(nnzc), ize(nnzc)
      dimension vf(mf)
!
      nxyf = nnxf*nnyf
      nxyc = nnxc*nnyc
!
! --- Loop over the coarse grid blocks, aggregate data from 
!     fine grid blocks, and determine volume-weighted, coarse 
!     grid block averages.
!
      do k = 1,nnzc
        do j = 1,nnyc
          do i = 1,nnxc
            nc = i + (j-1)*nnxc + (k-1)*nxyc
            iparamc(nc) = 0
            do m = 1,mf
              vf(m) = 0.d+0 
            end do
            do kk = izs(k),ize(k)
              if( cfzf(kk) .lt. cfzc(k) ) then
                dz = cfzf(kk+1) - cfzc(k)
                if( cfzc(k+1).le.cfzf(kk+1) ) dz = cfzc(k+1) - cfzc(k)
              elseif( cfzf(kk+1) .gt. cfzc(k+1) ) then
                dz = cfzc(k+1) - cfzf(kk)
              else
                dz = cfzf(kk+1) - cfzf(kk)
              endif
              do jj = iys(j),iye(j)
                if( cfyf(jj) .lt. cfyc(j) ) then
                  dy = cfyf(jj+1) - cfyc(j)
                  if( cfyc(j+1).le.cfyf(jj+1) ) dy = cfyc(j+1) - cfyc(j)
                elseif( cfyf(jj+1) .gt. cfyc(j+1) ) then
                  dy = cfyc(j+1) - cfyf(jj)
                else
                  dy = cfyf(jj+1) - cfyf(jj)
                endif
                do ii = ixs(i),ixe(i)
                  if( cfxf(ii) .lt. cfxc(i) ) then
                    dx = cfxf(ii+1) - cfxc(i)
                    if( cfxc(i+1).le.cfxf(ii+1) ) dx = cfxc(i+1)-cfxc(i)
                  elseif( cfxf(ii+1) .gt. cfxc(i+1) ) then
                    dx = cfxc(i+1) - cfxf(ii)
                  else
                    dx = cfxf(ii+1) - cfxf(ii)
                  endif
                  vo = dx*dy*dz
                  nf = ii + (jj-1)*nnxf + (kk-1)*nxyf
                  do m = 1,mf
                    if( iparamf(nf).eq.m ) then
! special treatment for cases with zero (inactive) regions
!                    if( iparamf(nf).eq.m-1 ) then
                      vf(m) = vf(m) + vo 
                      goto 321
                    endif
                  end do
  321             continue
!01.16.15
                  if( iparamf(nf).eq.0 ) vf(mf) = vf(mf) + vo
                end do
              end do
            end do
            vmax = 0.d+0
            do m = 1,mf
              if( vf(m).gt.vmax ) then 
                vmax = vf(m)
                imax = m 
!01.16.15 special case with zeros 
                if( imax.eq.mf ) imax = 0
              endif
            end do
            iparamc(nc) = imax
          end do
        end do
      end do
      return 
      end


      subroutine get_ptr( cfxf,cfyf,cfzf,cfxc,cfyc,cfzc,nnxf,nnyf,nnzf,&
                          nnxc,nnyc,nnzc,ixs,ixe,iys,iye,izs,ize )
! -------------------------------------------------------------------- !
!     Indexes the fine grid blocks that are contained within or that 
!     overlap each coarse grid block.
!
!     ML Rockhold, PNNL, November 22, 2004. 
! -------------------------------------------------------------------- !
      implicit real*8 (a-h,o-z)

      dimension cfxf(nnxf+1), cfyf(nnyf+1), cfzf(nnzf+1),&
                cfxc(nnxc+1), cfyc(nnyc+1), cfzc(nnzc+1) 
      dimension ixs(nnxc), ixe(nnxc), iys(nnyc), iye(nnyc),&
                izs(nnzc), ize(nnzc)
!
! --- Pointers in x-direction
!
      do 20 i = 1,nnxc
        isflg = 0
        ieflg = 0
        do 10 ii = 1,nnxf
          if( cfxf(ii+1) .gt. cfxc(i) ) then
            ixs(i) = ii
            isflg = 1
            goto 15
          endif
   10   continue
   15   ixe(i) = ixs(i)
        do 12 ii = ixs(i),nnxf
          if( cfxf(ii+1) .ge. cfxc(i+1) ) then
            ixe(i) = ii
            ieflg = 1
            goto 20
          endif
   12   continue
   20 continue
      if( isflg.eq.0 .or. ieflg.eq.0 ) stop 'ixs or ixe ptr not found'
!
! --- Pointers in y-direction
!
      do 40 j = 1,nnyc
        isflg = 0
        ieflg = 0
        do 30 jj = 1,nnyf
          if( cfyf(jj+1) .gt. cfyc(j) ) then
            iys(j) = jj
            isflg = 1
            goto 25
          endif
   30   continue
   25   iye(j) = iys(j)
        do 35 jj = iys(j),nnyf
          if( cfyf(jj+1) .ge. cfyc(j+1) ) then
            iye(j) = jj
            ieflg = 1
            goto 40
          endif
   35   continue
   40 continue
      if( isflg.eq.0 .or. ieflg.eq.0 ) stop 'iys or iye ptr not found'
!
! --- Pointers in z-direction
!
      do 60 k = 1,nnzc
        isflg = 0
        ieflg = 0
        do 50 kk = 1,nnzf
          if( cfzf(kk+1) .gt. cfzc(k) ) then
            izs(k) = kk
            isflg = 1
            goto 55
          endif
   50   continue
   55   ize(k) = izs(k)
        do 52 kk = izs(k),nnzf
          if( cfzf(kk+1) .ge. cfzc(k+1) ) then
            ize(k) = kk
            ieflg = 1
            goto 60
          endif
   52   continue
   60 continue
      if( isflg.eq.0 .or. ieflg.eq.0 ) stop 'izs or ize ptr not found'
      return
      end


!//////////////////////////////////////////////////////////////////////!
!  The following subroutines read and translate STOMP grid cards.
!  
!  Written by MD White, PNNL, date unknown.
!\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\!
!
!  subroutine lcase
!
      subroutine lcase( chdum )
      implicit real*8 (a-h,o-z)
      implicit integer*4 (i-n)
      character*(*) chdum
      do 10 n = 1,len(chdum)
        m = ichar(chdum(n:n))
        if( m .ge. 65 .and. m .le. 90 ) then
          m = m + 32
          chdum(n:n) = char(m)
        endif
   10 continue
      return
      end
! 
!  subroutine rdchar
! 
      subroutine rdchr( istart,icomma,nch,chdum,adum,varb )
      implicit real*8 (a-h,o-z)
      implicit integer*4 (i-n)
      character*(*) adum,varb
      character*(*) chdum
      nch = index( adum,'  ')-1
!
!  find next comma     
!
      icomma = index (chdum(istart:), ',') + istart - 1
      istop = icomma
  100 continue
!
!  comma not found, missing character string data     
!
      if( istop.lt.istart ) then
        write(6,'(2a)') 'Error: missing record: character: ',varb
        stop
!
!  null entry     
!
      elseif( istop.eq.istart ) then
        if( idflt .eq. 0 ) then
          adum = 'null'
          nch = 4
        endif
        istart = icomma + 1
        icomma = istart
!
!  characters between commas     
!
      else
!
!  eliminate leading blank spaces     
!
        if( ichar(chdum(istart:istart)).eq.32 ) then
          istart = istart+1
          goto 100
        endif
!
!  eliminate trailing blank spaces     
!
        istop = istop-1
  110   continue
        if( ichar(chdum(istop:istop)).eq.32 ) then
          istop = istop-1
          goto 110
        endif
!
!  translate character string into a character string     
!
        adum = ' '
        nch = istop-istart+1
        read (chdum(istart:istop), '(a)') adum(1:nch)
        istart = icomma + 1
      endif
      idflt = 0
      return
      end
!
!  subroutine rddpr
!
      subroutine rddpr( istart,icomma,chdum,var,varb )
      implicit real*8 (a-h,o-z)
      implicit integer*4 (i-n)
      character*(*) varb
      character*(*) chdum
      character*6 form1
      character*7 form2
      save form1,form2
      data form1 /'(d .0)'/
      data form2 /'(d  .0)'/
      ivr = index( varb,'  ')-1
!
!  find next comma  
!
      icomma = index (chdum(istart:), ',') + istart - 1
      istop = icomma
  100 continue
!
!  comma not found, missing real data  
!
      if( istop.lt.istart ) then
        write(6,'(2a)') 'Error: missing record: real: ',varb
        stop
!
!  null entry  
!
      elseif( istop.eq.istart ) then
        if( idflt .eq. 0 ) then
          var = 0.d+0
        endif
        istart = icomma + 1
        icomma = istart
      else
!
!  eliminate leading blank spaces  
!
        if( ichar(chdum(istart:istart)).eq.32 ) then
          istart = istart+1
          goto 100
        endif
!
!  eliminate trailing blank spaces  
!
        istop = istop-1
  110   continue
        if( ichar(chdum(istop:istop)).eq.32 ) then
          istop = istop-1
          goto 110
        endif
!
!  check for scientific notation  
!
        iexp = index( chdum(istart:istop),'e' )+istart-1
        iper = index( chdum(istart:istop),'.' )+istart-1
!
!  check for non-numerical characters  
!
        do 120 n = istart,istop
          if( n.eq.iexp .or. n.eq.iper ) goto 120
          nc = ichar(chdum(n:n))
          if( ( n.eq.istart .or. n.eq.iexp+1 ) .and. &
            ( nc.eq.43 .or. nc.eq.45 ) ) goto 120
          if( nc.lt.48 .or. nc.gt.57 ) then
            write(6,'(2a)') 'Error: non-numeric character: real: ',varb
            stop
          endif
  120   continue
!
!  translate character string into a double precision real  
!
        nchr = istop-istart+1
        if( nchr .lt. 10 ) then
          write( form1(3:3), '(i1)' ) nchr
          read (chdum(istart:istop), form1 ) var
        elseif( nchr .lt. 100 ) then
          write( form2(3:4), '(i2)' ) nchr
          read (chdum(istart:istop), form2 ) var
        else
          write(6,'(2a)') 'Error: excessive record length: real: ',varb
          stop
        endif
        istart = icomma + 1
      endif
      idflt = 0
      return
      end
!
!  subroutine rdint
!
      subroutine rdint( istart,icomma,chdum,ivar,varb )
      implicit real*8 (a-h,o-z)
      implicit integer*4 (i-n)
      character*(*) varb
      character*(*) chdum
      character*4 form1
      save form1
      data form1 /'(i )'/
      ivr = index( varb,'  ')-1
!
!  read numbers between commas  
!
      icomma = index (chdum(istart:), ',') + istart - 1
      istop = icomma
  100 continue
!
!  comma not found, missing integer data  
!
      if( istop.lt.istart ) then
        write(6,'(2a)') 'Error: missing record: integer: ',varb
        stop
!
!  null entry  
!
      elseif( istop.eq.istart ) then
        if( idflt .eq. 0 ) then
          ivar = 0
        endif
        istart = icomma + 1
        icomma = istart
!
!  characters between commas  
!
      else
!
!  eliminate leading blank spaces  
!
        if( ichar(chdum(istart:istart)).eq.32 ) then
          istart = istart+1
          goto 100
        endif
!
!  eliminate trailing blank spaces  
!
        istop = istop-1
  110   continue
        if( ichar(chdum(istop:istop)).eq.32 ) then
          istop = istop-1
          goto 110
        endif
!
!  check for non-numerical characters  
!
        do 120 n = istart,istop
          nc = ichar(chdum(n:n))
          if( n.eq.istart .and. ( nc.eq.43 .or. nc.eq.45 ) ) goto 120
          if( nc.lt.48 .or. nc.gt.57 ) then
            write(6,'(2a)') 'Error: non-numeric character: integer: ',&
             varb
            stop
          endif
  120   continue
!
!  translate character string into an integer  
!
        nchr = istop-istart+1
        if( nchr.lt.10 ) then
          write( form1(3:3),'(i1)' ) nchr
          read( chdum(istart:istop),form1 ) ivar
        else
          write(6,'(2a)') 'Error: excessive record length: integer: ',&
           varb
          stop
        endif
        istart = icomma + 1
      endif
      idflt = 0
      return
      end
!
!  subroutine rdunit
!
      subroutine rdunit( unts,var,iunm,iunkg,iuns,iunk,iunmol,indx )
      implicit real*8 (a-h,o-z)
      implicit integer*4 (i-n)
      parameter (luns=74)
      character*4 form1
      character*8 chs(luns),chd
      character*64 chmsg,varb
      character*(*) unts
      real*8 cf(luns)
      integer*4 ium(luns),iukg(luns),ius(luns),iuk(luns),iumol(luns)
      save chs,cf,ium,iukg,ius,iuk,iumol,form1
      data chs /'m','kg','s','j','c','pa','w','kgmol','rad',&
       'solid','water','napl','gas','aqueous','oil','voc','sol',&
       'ci','pci','liq','aqu',&
       'ft','cm','mm','yd','in','l','gal','liter',&
       'ml','g','lb','slug','lbm','gm','gram','mg',&
       'min','hr','d','wk','yr',&
       'hour','day','week','year','sec',&
       'btu','cal','hp','dynes','dyn','darcy',&
       'k','f','r',&
       'psi','bar','atm','wh','psf','lbf',&
       'deg','degree','furlong','rod',&
       'cp','p','hc','1','mol','mole','lbmol',&
       'debyes'/
      data cf  /1.e+0,1.e+0,1.e+0,1.e+0,1.e+0,1.e+0,1.e+0,1.e+0,1.e+0,&
       1.e+0,1.e+0,1.e+0,1.e+0,1.e+0,1.e+0,1.e+0,1.e+0,&
       1.e+0,1.e+0,1.e+0,1.e+0,&
       3.048e-1,1.e-2,1.e-3,9.144e-1,2.54e-2,1.e-3,3.7854e-3,1.e-3,&
       1.e-6,1.e-3,4.5359e-1,1.4594e+1,4.5359e-1,1.e-3,1.e-3,1.e-6,&
       6.e+1,3.6e+3,8.64e+4,6.048e+5,3.15576e+7,&
       3.6e+3,8.64e+4,6.048e+5,3.15576e+7,1.e+0,&
       1.0544e+3,4.184e+0,7.457e+2,1.e-5,1.e-5,0.9869e-12,&
       1.e+0,5.555556e-1,5.555556e-1,&
       6.8948e+3,1.e+5,1.01325e+5,9.7935332e+03,4.7880556e+1,4.4482e+0,&
       1.745329252e-2,1.745329252e-2,2.01168e+2,5.0292e+0,&
       1.e-3,1.e-1,1.0391029519945587e-07,1.e+0,1.e-3,1.e-3,4.5359e-1,&
       1.e+0/
      data ium /1,0,0,2,0,-1,2,0,0,&
       0,0,0,0,0,0,0,0,&
       0,0,0,0,&
       1,1,1,1,1,3,3,3,&
       3,0,0,0,0,0,0,0,&
       0,0,0,0,0,&
       0,0,0,0,0,&
       2,2,2,1,1,2,&
       0,0,0,&
       -1,-1,-1,-2,-1,1,&
       0,0,1,1,&
       -1,-1,0,0,0,0,0,&
       0/
      data iukg /0,1,0,1,0,1,1,0,0,&
       0,0,0,0,0,0,0,0,&
       0,0,0,0,&
       0,0,0,0,0,0,0,0,&
       0,1,1,1,1,1,1,1,&
       0,0,0,0,0,&
       0,0,0,0,0,&
       1,1,1,1,1,0,&
       0,0,0,&
       1,1,1,1,1,1,&
       0,0,0,0,&
       1,1,0,0,0,0,0,&
       0/
      data ius /0,0,1,-2,0,-2,-3,0,0,&
       0,0,0,0,0,0,0,0,&
       0,0,0,0,&
       0,0,0,0,0,0,0,0,&
       0,0,0,0,0,0,0,0,&
       1,1,1,1,1,&
       1,1,1,1,1,&
       -2,-2,-3,-2,-2,0,&
       0,0,0,&
       -2,-2,-2,-2,-2,-2,&
       0,0,0,0,&
       -1,-1,0,0,0,0,0,&
       0/
      data iuk /0,0,0,0,1,0,0,0,0,&
       0,0,0,0,0,0,0,0,&
       0,0,0,0,&
       0,0,0,0,0,0,0,0,&
       0,0,0,0,0,0,0,0,&
       0,0,0,0,0,&
       0,0,0,0,0,&
       0,0,0,0,0,0,&
       1,1,1,&
       0,0,0,0,0,0,&
       0,0,0,0,&
       0,0,0,0,0,0,0,&
       0/
      data iumol /0,0,0,0,0,0,0,1,0,&
       0,0,0,0,0,0,0,0,&
       0,0,0,0,&
       0,0,0,0,0,0,0,0,&
       0,0,0,0,0,0,0,0,&
       0,0,0,0,0,&
       0,0,0,0,0,&
       0,0,0,0,0,0,&
       0,0,0,&
       0,0,0,0,0,0,&
       0,0,0,0,&
       0,0,0,0,1,1,1,&
       0/
      data form1 /'(i )'/
      if( unts .eq. 'null' .or. unts .eq. 'none' ) then
        iunm = 0
        iunkg = 0
        iuns = 0
        iunk = 0
        iunmol = 0
        return
      endif
!
!  intialize primary unit indices  
!
      iumx = 0
      iukgx = 0
      iusx = 0
      iukx = 0
      iumolx = 0
!
!  temperature units  --
!
      if( unts .eq. 'c' ) then
        iukx = 1
        goto 400
      elseif( unts .eq. 'k' ) then
        if( indx.eq.0 .or. indx.eq.2 ) then
          var = var - 2.7315e+2
        else
          var = var + 2.7315e+2
        endif
        iukx = 1
        goto 400
      elseif( unts .eq. 'f' ) then
        if( indx.eq.0 .or. indx.eq.2 ) then
          var = (var-3.2e+1)/1.8e+0
        else
          var = var*1.8e+0 + 3.2e+1
        endif
        iukx = 1
        goto 400
      elseif( unts .eq. 'r' ) then
        if( indx.eq.0 .or. indx.eq.2 ) then
          var = (var-4.92e+2)/1.8e+0
        else
          var = var*1.8e+0 + 4.92e+2
        endif
        iukx = 1
        goto 400
      endif
!
!  decompose the units into components and convert individual 
!     components  
!
      is = 1
      idv = index( unts(1:),'/' )-1
      ie = index( unts(1:),'  ' )-1
!
!  units without a divisor  
!
      if( idv .eq. -1 ) then
  100 continue
        isp = index( unts(is:),' ' )+is-2
        ico = index( unts(is:),':' )+is-2
        if( ico .lt. is ) ico = ie
        ib = min( ie,isp,ico )
        chd = unts(is:ib)
        ic = index( chd(1:),'^' )
        if( ic .eq. 0 ) then
          ip = 1
        else
          i1 = ic+1
          i2 = ib-is+1
          i3 = i2-i1+1
          write( form1(3:3),'(i1)' ) i3
          read(chd(i1:i2),form1) ip
          i2 = ic-1
          chd = chd(1:i2)
        endif
        do 110 n = 1,luns
          if( chs(n) .eq. chd ) then
            iumx = iumx + ium(n)*ip
            iukgx = iukgx + iukg(n)*ip
            iusx = iusx + ius(n)*ip
            iukx = iukx + iuk(n)*ip
            iumolx = iumolx + iumol(n)*ip
            if( indx.eq.0 .or. indx.eq.2 ) then
              var = var*(cf(n)**ip)
            else
              var = var/(cf(n)**ip)
            endif
            goto 120
          endif
  110   continue
        if( indx.eq.0 .or. indx.eq.2 ) then
          chmsg = varb(1:ivr)//', '//unts
          nch = index(chmsg,'  ')-1
          write(6,'(2a)') 'Error: unrecognized units: ',chmsg(1:nch)
          stop
        else
          chmsg = 'output variable, '//unts
          nch = index(chmsg,'  ')-1
          write(6,'(2a)') 'Error: unrecognized units: ',chmsg(1:nch)
          stop
        endif       
  120   continue
        if( ib .lt. ie ) then
          is = ib+2
          goto 100
        endif
!
!  units with a divisor  
!
      else
!
!  components before the divisor  
!
  200 continue 
        isp = index( unts(is:),' ' )+is-2
        ico = index( unts(is:),':' )+is-2
        if( ico .lt. is ) ico = ie
        ib = min( idv,isp,ico )
        chd = unts(is:ib)
        ic = index( chd(1:),'^' )
        if( ic .eq. 0 ) then
          ip = 1
        else
          i1 = ic+1
          i2 = ib-is+1
          i3 = i2-i1+1
          write( form1(3:3),'(i1)' ) i3
          read(chd(i1:i2),form1) ip
          i2 = ic-1
          chd = chd(1:i2)
        endif
        do 210 n = 1,luns
          if( chs(n) .eq. chd ) then
            iumx = iumx + ium(n)*ip
            iukgx = iukgx + iukg(n)*ip
            iusx = iusx + ius(n)*ip
            iukx = iukx + iuk(n)*ip
            iumolx = iumolx + iumol(n)*ip
            if( indx.eq.0 .or. indx.eq.2 ) then
              var = var*(cf(n)**ip)
            else
              var = var/(cf(n)**ip)
            endif
            goto 220
          endif
  210   continue
        if( indx.eq.0 .or. indx.eq.2 ) then
          chmsg = varb(1:ivr)//', '//unts
          nch = index(chmsg,'  ')-1
          write(6,'(2a)') 'Error: unrecognized units: ',chmsg(1:nch)
          stop
        else
          chmsg = 'output variable, '//unts
          nch = index(chmsg,'  ')-1
          write(6,'(2a)') 'Error: unrecognized units: ',chmsg(1:nch)
          stop
        endif       
  220   continue
        if( ib .lt. idv ) then
          is = ib+2
          goto 200
        else
          is = ib+2
          goto 300
        endif
!
!  components after the divisor  
!
  300   continue
        isp = index( unts(is:),' ' )+is-2
        ico = index( unts(is:),':' )+is-2
        if( ico .lt. is ) ico = ie
        ib = min( ie,isp,ico )
        chd = unts(is:ib)
        ic = index( chd(1:),'^' )
        if( ic .eq. 0 ) then
          ip = 1
        else
          i1 = ic+1
          i2 = ib-is+1
          i3 = i2-i1+1
          write( form1(3:3),'(i1)' ) i3
          read(chd(i1:i2),form1) ip
          i2 = ic-1
          chd = chd(1:i2)
        endif
        do 310 n = 1,luns
          if( chs(n) .eq. chd ) then
            iumx = iumx - ium(n)*ip
            iukgx = iukgx - iukg(n)*ip
            iusx = iusx - ius(n)*ip
            iukx = iukx - iuk(n)*ip
            iumolx = iumolx - iumol(n)*ip
            if( indx.eq.0 .or. indx.eq.2 ) then
              var = var/(cf(n)**ip)
            else
              var = var*(cf(n)**ip)
            endif
            goto 320
          endif
  310   continue
        if( indx.eq.0 .or. indx.eq.2 ) then
          chmsg = varb(1:ivr)//', '//unts
          nch = index(chmsg,'  ')-1
          write(6,'(2a)') 'Error: unrecognized units: ',chmsg(1:nch)
          stop
        else
          chmsg = 'output variable, '//unts
          nch = index(chmsg,'  ')-1
          write(6,'(2a)') 'Error: unrecognized units: ',chmsg(1:nch)
          stop
        endif       
  320   continue
        if( ib .lt. ie ) then
          is = ib+2
          goto 300
        endif
      endif
!
!  units conversion check  
!
  400 continue
      if( indx.eq.2 ) then
        iunm = 0
        iunkg = 0
        iuns = 0
        iunk = 0
        iunmol = 0
      elseif( iumx.ne.iunm .or. iukgx.ne.iunkg .or. iusx.ne.iuns .or.&
          iukx.ne.iunk .or. iumolx.ne.iunmol ) then
        if( indx.eq.0 .or. indx.eq.2 ) then
          chmsg = varb(1:ivr)//', '//unts
          nch = index(chmsg,'  ')-1
          write(6,'(2a)') 'Error: incompatible units: ',chmsg(1:nch)
          stop
        else
          chmsg = 'output variable, '//unts
          nch = index(chmsg,'  ')-1
          write(6,'(2a)') 'Error: incompatible units: ',chmsg(1:nch)
          stop
        endif       
      else
        iunm = 0
        iunkg = 0
        iuns = 0
        iunk = 0
        iunmol = 0
      endif
      return
      end
!
!  subroutine rdgrid
!
      subroutine rdgrid(x,y,z,xp,yp,zp,ifld,jfld,kfld,lfx,lfy,lfz)
      implicit real*8 (a-h,o-z)
      implicit integer*4 (i-n)
      real*8 xp(*),yp(*),zp(*)
      real*8 x(lfx+1),y(lfy+1),z(lfz+1)
      character*64 adum,unts,varb,chmsg
!      character*515 chdum
      character*5000 chdum
      iunm = 0
      iunkg = 0
      iuns = 0
      iunk = 0
      iunmol = 0
!
!  read coordinate system type  
!
   91 read (20,'(a)') chdum
      if( chdum(1:1).eq.'#' .or. chdum(1:1).eq.'!' ) goto 91
      call lcase( chdum )
      istart = 1
      varb = 'coordinate system'
      call rdchr(istart,icomma,nch,chdum,adum,varb)
      if( index(adum(1:),'cartesian').ne.0 ) then
        if( index(adum(1:),'uniform').ne.0 ) then
          ics = 5
        else
          ics = 1
        endif
      elseif( index(adum(1:),'cylindrical').ne.0 ) then
        if( index(adum(1:),'uniform').ne.0 ) then
          ics = 6
        else
          ics = 2
        endif
      elseif( index(adum(1:),'tilted').ne.0 ) then
        ics = 1
        varb = 'x-z plane horizontal tilt'
        call rddpr(istart,icomma,chdum,thxz,varb)
        varb = 'x-z plane horizontal tilt units'
        call rdchr(istart,icomma,nch,chdum,unts,varb)
        indx = 0
        call rdunit( unts,thxz,iunm,iunkg,iuns,iunk,iunmol,indx )
        varb = 'y-z plane horizontal tilt'
        call rddpr(istart,icomma,chdum,thyz,varb)
        varb = 'y-z plane horizontal tilt units'
        call rdchr(istart,icomma,nch,chdum,unts,varb)
        indx = 0
        call rdunit( unts,thyz,iunm,iunkg,iuns,iunk,iunmol,indx )
        gravx = grav*sin(thxz)*cos(thyz)
        gravy = grav*cos(thxz)*sin(thyz)
        gravz = grav*cos(thxz)*cos(thyz)
      else
        chmsg = adum
        nch = index(chmsg,'  ')-1
        write(6,'(2a)') 'Error: unrecognized coordinate type',&
          chmsg(1:nch)
        stop
      endif
!
!  read coordinate system node dimensions  
!
      istart = 1
   92 read (20,'(a)') chdum
      if( chdum(1:1).eq.'#' .or. chdum(1:1).eq.'!' ) goto 92
      call lcase( chdum )
      varb = 'number of i-indexed nodes'
      call rdint(istart,icomma,chdum,ifld,varb)
      varb = 'number of j-indexed nodes'
      call rdint(istart,icomma,chdum,jfld,varb)
      varb = 'number of k-indexed nodes'
      call rdint(istart,icomma,chdum,kfld,varb)
!
!  check coordinate sytem dimensions against parameter sizes 
!
      if( ifld.lt.1  ) then
        write(6,'(a)') 'Error: ifld < 1'
        stop
      elseif( ifld.gt.lfx ) then
        write(6,'(a)') 'Error: ifld > lfx'
        stop
      elseif( jfld.lt.1  ) then
        write(6,'(a)') 'Error: jfld < 1'
        stop
      elseif( jfld.gt.lfy ) then
        write(6,'(a)') 'Error: jfld > lfy'
        stop
      elseif( kfld.lt.1  ) then
        write(6,'(a)') 'Error: kfld < 1'
        stop
      elseif( kfld.gt.lfz ) then
         write(6,'(a)') 'Error: kfld > lfz'
        stop
      endif
!
!  uniform cartesian grid 
!
      if( ics.eq.5 .or. ics.eq.6 ) then
        istart = 1
  193   read (20,'(a)') chdum
        if( chdum(1:1).eq.'#' .or. chdum(1:1).eq.'!' ) goto 193
        call lcase( chdum )
        if( ics.eq.6 ) then
          varb = 'radial node dimension'
        else
          varb = 'x node dimension'
        endif
        call rddpr(istart,icomma,chdum,xspc,varb)
        if( ics.eq.6 ) then
          varb = 'radial node dimension units'
        else
          varb = 'x node dimension units'
        endif
        call rdchr(istart,icomma,nch,chdum,unts,varb)
        i = 1
        x(1) = 0.d+0
        do 20 i = 2,ifld+1
          x(i) = x(i-1)+xspc
   20   continue
        indx = 0
        do 30 i = 1,ifld+1
          iunm = 1
          call rdunit( unts,x(i),iunm,iunkg,iuns,iunk,iunmol,indx )
   30   continue
      else
        ic = 0
  100   continue
        istart = 1
   93   read (20,'(a)') chdum
        if( chdum(1:1).eq.'#' .or. chdum(1:1).eq.'!' ) goto 93
        call lcase( chdum )
        ir = ifld+1-ic
        do 102 i = 1,ir
          icm = index( chdum(istart:), ',' ) + istart - 1
          if( icm.eq.istart-1 ) goto 100
          iat = index( chdum(istart:), '@' ) + istart - 1
          if( iat.lt.istart .or. iat.gt.icm ) then
            ic = ic + 1
            varb = 'x dimension'
            call rddpr(istart,icomma,chdum,x(ic),varb)
            varb = 'x dimension units'
            call rdchr(istart,icomma,nch,chdum,unts,varb)
            indx = 0
            iunm = 1
            call rdunit( unts,x(ic),iunm,iunkg,iuns,iunk,iunmol,indx )
            if( ic.eq.ifld+1 ) goto 103
          else
            chdum(iat:iat) = ','
            varb = 'count integer'
            call rdint(istart,icomma,chdum,iat,varb)
            varb = 'x dimension'
            call rddpr(istart,icomma,chdum,dxvar,varb)
            varb = 'x dimension units'
            call rdchr(istart,icomma,nch,chdum,unts,varb)
            indx = 0
            iunm = 1
            call rdunit( unts,dxvar,iunm,iunkg,iuns,iunk,iunmol,indx )
            do 101 ii = 1,iat
              ic = ic + 1
              if( ic.eq.1 ) then
                x(ic) = 0.d+0
              else
                x(ic) = x(ic-1) + dxvar
              endif
              xvar = x(ic)
              indx = 1
              iunm = 1
              call rdunit( unts,xvar,iunm,iunkg,iuns,iunk,iunmol,indx )
              if( ic.eq.ifld+1 ) goto 103
  101       continue
          endif
  102   continue
  103   continue
      endif
      if( ics.eq.5 .or. ics.eq.6 ) then
        istart = 1
  194   read (20,'(a)') chdum
        if( chdum(1:1).eq.'#' .or. chdum(1:1).eq.'!' ) goto 194
        call lcase( chdum )
        if( ics.eq.6 ) then
          varb = 'azimuthal node dimension'
        else
          varb = 'y node dimension'
        endif
        call rddpr(istart,icomma,chdum,yspc,varb)
        if( ics.eq.6 ) then
          varb = 'azimuthal node dimension units'
        else
          varb = 'y node dimension units'
        endif
        call rdchr(istart,icomma,nch,chdum,unts,varb)
        j = 1
        y(1) = 0.d+0
        do 120 j = 2,jfld+1
          y(j) = y(j-1)+yspc
  120   continue
        indx = 0
        do 130 j = 1,jfld+1
          iunm = 1
          if( ics.eq.6 ) iunm = 0
          call rdunit( unts,y(j),iunm,iunkg,iuns,iunk,iunmol,indx )
  130   continue
      else
        jc = 0
  200   continue
        istart = 1
   94   read (20,'(a)') chdum
        if( chdum(1:1).eq.'#' .or. chdum(1:1).eq.'!' ) goto 94
        call lcase( chdum )
        jr = jfld+1-jc
        do 202 j = 1,jr
          jcm = index( chdum(istart:), ',' ) + istart - 1
          if( jcm.eq.istart-1 ) goto 200
          jat = index( chdum(istart:), '@' ) + istart - 1
          if( jat.lt.istart .or. jat.gt.jcm ) then
            jc = jc + 1
            varb = 'y dimension'
            call rddpr(istart,icomma,chdum,y(jc),varb)
            varb = 'y dimension units'
            call rdchr(istart,icomma,nch,chdum,unts,varb)
            indx = 0
            iunm = 1
            if( ics.eq.2 ) iunm = 0
            call rdunit( unts,y(jc),iunm,iunkg,iuns,iunk,iunmol,indx )
            if( jc.eq.jfld+1 ) goto 203
          else
            chdum(jat:jat) = ','
            varb = 'count integer'
            call rdint(istart,icomma,chdum,jat,varb)
            varb = 'y dimension'
            call rddpr(istart,icomma,chdum,dyvar,varb)
            varb = 'y dimension units'
            call rdchr(istart,icomma,nch,chdum,unts,varb)
            indx = 0
            iunm = 1
            if( ics.eq.2 ) iunm = 0
            call rdunit( unts,dyvar,iunm,iunkg,iuns,iunk,iunmol,indx )
            do 201 jj = 1,jat
              jc = jc + 1
              if( jc.eq.1 ) then
                y(jc) = 0.d+0
              else
                y(jc) = y(jc-1) + dyvar
              endif
              yvar = y(jc)
              indx = 1
              iunm = 1
              if( ics.eq.2 ) iunm = 0
              call rdunit( unts,yvar,iunm,iunkg,iuns,iunk,iunmol,indx )
              if( jc.eq.jfld+1 ) goto 203
  201       continue
          endif
  202   continue
  203   continue
      endif
      if( ics.eq.5 .or. ics.eq.6 ) then
        istart = 1
  195   read (20,'(a)') chdum
        if( chdum(1:1).eq.'#' .or. chdum(1:1).eq.'!' ) goto 195
        call lcase( chdum )
        if( ics.eq.6 ) then
          varb = 'vertical node dimension'
        else
          varb = 'z node dimension'
        endif
        call rddpr(istart,icomma,chdum,zspc,varb)
        if( ics.eq.6 ) then
          varb = 'vertical node dimension units'
        else
          varb = 'z node dimension units'
        endif
        call rdchr(istart,icomma,nch,chdum,unts,varb)
        k = 1
        z(1) = 0.d+0
        do 220 k = 2,kfld+1
          z(k) = z(k-1)+zspc
  220   continue
        indx = 0
        do 230 k = 1,kfld+1
          iunm = 1
          call rdunit( unts,z(k),iunm,iunkg,iuns,iunk,iunmol,indx )
  230   continue
      else
        kc = 0
  300   continue
        istart = 1
   95   read (20,'(a)') chdum
        if( chdum(1:1).eq.'#' .or. chdum(1:1).eq.'!' ) goto 95
        call lcase( chdum )
        kr = kfld+1-kc
        do 302 k = 1,kr
          kcm = index( chdum(istart:), ',' ) + istart - 1
          if( kcm.eq.istart-1 ) goto 300
          kat = index( chdum(istart:), '@' ) + istart - 1
          if( kat.lt.istart .or. kat.gt.kcm ) then
            kc = kc + 1
            varb = 'z dimension'
            call rddpr(istart,icomma,chdum,z(kc),varb)
            varb = 'z dimension units'
            call rdchr(istart,icomma,nch,chdum,unts,varb)
            indx = 0
            iunm = 1
            call rdunit( unts,z(kc),iunm,iunkg,iuns,iunk,iunmol,indx )
            if( kc.eq.kfld+1 ) goto 303
          else
            chdum(kat:kat) = ','
            varb = 'count integer'
            call rdint(istart,icomma,chdum,kat,varb)
            varb = 'z dimension'
            call rddpr(istart,icomma,chdum,dzvar,varb)
            varb = 'z dimension units'
            call rdchr(istart,icomma,nch,chdum,unts,varb)
            indx = 0
            iunm = 1
            call rdunit( unts,dzvar,iunm,iunkg,iuns,iunk,iunmol,indx )
            do 301 kk = 1,kat
              kc = kc + 1
              if( kc.eq.1 ) then
                z(kc) = 0.d+0
              else
                z(kc) = z(kc-1) + dzvar
              endif
              zvar = z(kc)
              indx = 1
              iunm = 1
              call rdunit( unts,zvar,iunm,iunkg,iuns,iunk,iunmol,indx )
              if( kc.eq.kfld+1 ) goto 303
  301       continue
          endif
  302   continue
  303   continue
      endif
      if( ics.eq.5 ) ics = 1
      if( ics.eq.6 ) ics = 2
!
!  define i-indexed physical length data 
!
      if( ics.eq.1 ) then
        do 510 i = 1,ifld
          xp(i) = 5.d-1*(x(i)+x(i+1))
  510   continue
      elseif( ics.eq.2 ) then
        x(1) = max( small,x(1) )
        do 530 i = 1,ifld
          xp(i) = 5.d-1*(x(i)+x(i+1))
  530   continue
      endif
!
!  define j-indexed physical length data 
!
      if( ics.ge.1) then
        do 610 j = 1,jfld
          yp(j) = 5.d-1*(y(j)+y(j+1))
  610   continue
      endif
!
!  define k-indexed physical length data 
!
      if( ics.ge.1) then
        do 710 k = 1,kfld
          zp(k) = 5.d-1*(z(k)+z(k+1))
  710   continue
      endif
      return
      end

!
!  function ndigit
!
      function ndigit(i)
      implicit real*8 (a-h,o-z)
      implicit integer*4 (i-n)
      ndigit = 0
      ic = i
   10 continue
      ic = ic/10
      ndigit = ndigit+1
      if( ic.eq.0 ) goto 20
      goto 10
   20 continue
      return
      end
