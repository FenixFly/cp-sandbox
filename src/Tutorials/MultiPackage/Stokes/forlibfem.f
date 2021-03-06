C ======================================================================
c Templated routine for elemental matrix
C ======================================================================
      Subroutine fem3Dext( 
     &           XY1, XY2, XY3, XY4,
     &           lbE, lbF, lbR, lbP, DATA, iSYS,
     &           LDA, A, F, nRow, nCol,
     &           templateR, templateC)
      Include 'fem3Dtet.fd'
      Include 'assemble.fd'
C ======================================================================
      Real*8  XY1(*), XY2(*), XY3(*), XY4(*)
      
      Integer lbE, lbF(4), lbR(6), lbP(4)
      Real*8  DATA(*)
      Integer iSYS(*)

      Real*8  A(LDA, *), F(*)
      Integer templateR(*), templateC(*)

C Local variables
      Integer  Ddiff, Drhs, Dbc, ANI_Dnull
      External Ddiff, Drhs, Dbc, ANI_Dnull

      Real*8   B(30, 30), XYP(3, 4)
      Real*8   x, y, z, eBC(3)
C ======================================================================
      Do i = 1, 3
         XYP(i, 1) = XY1(i)
         XYP(i, 2) = XY2(i)
         XYP(i, 3) = XY3(i)
         XYP(i, 4) = XY4(i)
      End do

c ... size of the elemental problem (30 velocities + 4 pressures)
      nRow = 34 
      nCol = 34

c ... set up templates 
      Do i = 1, 4
         templateR(i)      = Vdof   !u_x
         templateR(i + 10) = Vdof   !u_y
         templateR(i + 20) = Vdof   !u_z

         templateR(i + 30) = Vdof   !p
      End do

      Do i = 1, 6
         templateR(i + 4)  = Rdof
         templateR(i + 14) = Rdof
         templateR(i + 24) = Rdof
      End do

      Do k = 1, nRow
         templateC(k) = templateR(k)
      End do

c ... compute the stiffness matrix (M)
      label = lbE

c     A(1:30,1:30) is local vector Laplacian matrix for three velocity components
      Call fem3Dtet(XY1, XY2, XY3, XY4,
     &              GRAD, FEM_P2vector, GRAD, FEM_P2vector,
     &              label, Ddiff, DATA, iSYS, 2,
     &              LDA, A, ir, ic)
      
c     B(1:4,1:30) is local divergence matrix for velocity
      Call fem3Dtet(XY1, XY2, XY3, XY4,
     &              DIV, FEM_P2vector, IDEN, FEM_P1,
     &              label, ANI_Dnull, DATA, iSYS, 2,
     &              30, B, ir, ic)

      Do i = 1, 30
         Do j = 1, 4
            A(i, j + 30) = -B(j, i)
            A(j + 30, i) = -B(j, i)
         End do
      End do

      Do i = 1, 4
         Do j = 1, 4
            A(i + 30, j + 30) = 0
         End do
      End do

c ... compute the right hand side
      Call fem3Dtet(XY1, XY2, XY3, XY4,
     &              IDEN, FEM_P0, IDEN, FEM_P2vector, 
     &              lbE, Drhs, DATA, iSYS, 2,
     &              LDA, F, ir, ic)

      Do i = 1, 4
         F(i + 30) = 0
      End do

c ... impose boundary conditions at vertices of tetrahedron
      Do k = 1, 4
         If(lbP(k).ne.0) Then
            x = XYP(1, k)
            y = XYP(2, k)
            z = XYP(3, k)

c  ...  Dbc will change iSYS(1:2)
            ibc = Dbc(x, y, z, lbP(k), DATA, iSYS, eBC)

            If(ibc.EQ.BC_DIRICHLET) Then
               Call applyDIR(LDA, nRow, A, F, k,    eBC(1))
               Call applyDIR(LDA, nRow, A, F, k+10, eBC(2))
               Call applyDIR(LDA, nRow, A, F, k+20, eBC(3))
            End if
         End if
      End do

c ... impose boundary conditions (assume nRow = nCol) at mid-points of edges
      k = 0
      Do i = 1, 3
         Do j = i + 1, 4  
            k = k + 1

            If(lbP(i).GT.0 .AND. lbP(j).GT.0) Then
               x = (XYP(1, i) + XYP(1, j)) / 2
               y = (XYP(2, i) + XYP(2, j)) / 2
               z = (XYP(3, i) + XYP(3, j)) / 2

c  ...  Dbc will change iSYS(1:2)
               ibc = Dbc(x, y, z, lbP(i), DATA, iSYS, eBC)

               If(ibc.EQ.BC_DIRICHLET) Then
                  Call applyDIR(LDA, nRow, A, F, k+4,  eBC(1))
                  Call applyDIR(LDA, nRow, A, F, k+14, eBC(2))
                  Call applyDIR(LDA, nRow, A, F, k+24, eBC(3))
               End if
            End if
         End do
      End do

      Return
      End



C ======================================================================
C Identity tensor
      Integer Function Ddiff(x, y, z, label, DATA, iSYS, Coef)
C ======================================================================
      include 'fem3Dtet.fd'

      Real*8  x, y, z, DATA(*), Coef(9, 9)
      Integer iSYS(*)

C ======================================================================
      iSYS(1) = 1
      iSYS(2) = 1

      Coef(1, 1) = 1
      Ddiff = TENSOR_SCALAR
      Return
      End



C ======================================================================
C boundary conditions
      Integer Function Dbc(x, y, z, label, DATA, iSYS, Coef)
C ======================================================================
      Include 'assemble.fd'

      Real*8  x, y, z, DATA(*), Coef(*)
      Integer iSYS(*)

C ======================================================================
      iSYS(1) = 1
      iSYS(2) = 3
      If(label.eq.3) Then
         Coef(1) = (y - 0.5) * z * (1 - y) * (1 - z) * 64
         Coef(2) = 0
         Coef(3) = 0
         Dbc = BC_DIRICHLET
      Else If(label.eq.5) Then
         Coef(1) = 0
         Coef(2) = 0
         Coef(3) = 0
         Dbc = BC_NEUMANN
      Else
         Coef(1) = 0
         Coef(2) = 0
         Coef(3) = 0
         Dbc = BC_DIRICHLET
      End if
      Return
      End



C ======================================================================
C Right hand side
      Integer Function Drhs(x, y, z, label, DATA, iSYS, Coef)
C ======================================================================
      Include 'fem3Dtet.fd'

      Real*8  x, y, z, DATA(*), Coef(*)
      Integer iSYS(*)

C ======================================================================
      iSYS(1) = 3
      iSYS(2) = 1

      Coef(1) = 0D0
      Coef(2) = 0D0
      Coef(3) = 0D0
      Drhs = TENSOR_GENERAL

      Return
      End 


C ======================================================================
c Templated routine for elemental stiffness matrix P2
C ======================================================================
      Subroutine fem3DextLaplP2( 
     &           XY1, XY2, XY3, XY4,
     &           lbE, lbF, lbR, lbP, DATA, iSYS,
     &           LDA, A, F, nRow, nCol,
     &           templateR, templateC)
      Include 'fem3Dtet.fd'
      Include 'assemble.fd'
C ======================================================================
      Real*8  XY1(*), XY2(*), XY3(*), XY4(*)
      
      Integer lbE, lbF(4), lbR(6), lbP(4)
      Real*8  DATA(*)
      Integer iSYS(*)

      Real*8  A(LDA, *), F(*)
      Integer templateR(*), templateC(*)

C Local variables
      Integer  Ddiff,  Dbc
      External Ddiff,  Dbc

      Real*8   XYP(3, 4)
      Real*8   x, y, z, eBC(3)
C ======================================================================
      Do i = 1, 3
         XYP(i, 1) = XY1(i)
         XYP(i, 2) = XY2(i)
         XYP(i, 3) = XY3(i)
         XYP(i, 4) = XY4(i)
      End do

c ... size of the elemental problem (10 velocities)
      nRow = 10 
      nCol = 10

c ... set up templates 
      Do i = 1, 4
         templateR(i)      = Vdof   
      End do

      Do i = 1, 6
         templateR(i + 4)  = Rdof
      End do

      Do k = 1, nRow
         templateC(k) = templateR(k)
      End do

c ... compute the stiffness matrix (M)
      label = lbE

c     A(1:10,1:10) is local Laplacian matrix for P2 functions
      Call fem3Dtet(XY1, XY2, XY3, XY4,
     &              GRAD, FEM_P2, GRAD, FEM_P2,
     &              label, Ddiff, DATA, iSYS, 2,
     &              LDA, A, ir, ic)
      

c ... impose boundary conditions at vertices of tetrahedron
      Do k = 1, nRow
         F(k) = 0
      End do
      Do k = 1, 4
         If(lbP(k).ne.0) Then
            x = XYP(1, k)
            y = XYP(2, k)
            z = XYP(3, k)

c  ...  Dbc will change iSYS(1:2)
            ibc = Dbc(x, y, z, lbP(k), DATA, iSYS, eBC)

            If(ibc.EQ.BC_DIRICHLET) Then
               Call applyDIR(LDA, nRow, A, F, k,    eBC(1))
            End if
         End if
      End do

c ... impose boundary conditions (assume nRow = nCol) at mid-points of edges
      k = 0
      Do i = 1, 3
         Do j = i + 1, 4  
            k = k + 1

            If(lbP(i).GT.0 .AND. lbP(j).GT.0) Then
               x = (XYP(1, i) + XYP(1, j)) / 2
               y = (XYP(2, i) + XYP(2, j)) / 2
               z = (XYP(3, i) + XYP(3, j)) / 2

c  ...  Dbc will change iSYS(1:2)
               ibc = Dbc(x, y, z, lbP(i), DATA, iSYS, eBC)

               If(ibc.EQ.BC_DIRICHLET) Then
                  Call applyDIR(LDA, nRow, A, F, k+4,  eBC(1))
               End if
            End if
         End do
      End do

      Return
      End
C ======================================================================
c Templated routine for elemental mass matrix P1
C ======================================================================
      Subroutine fem3DextMassP1( 
     &           XY1, XY2, XY3, XY4,
     &           lbE, lbF, lbR, lbP, DATA, iSYS,
     &           LDA, A, F, nRow, nCol,
     &           templateR, templateC)
      Include 'fem3Dtet.fd'
      Include 'assemble.fd'
C ======================================================================
      Real*8  XY1(*), XY2(*), XY3(*), XY4(*)
      
      Integer lbE, lbF(4), lbR(6), lbP(4)
      Real*8  DATA(*)
      Integer iSYS(*)

      Real*8  A(LDA, *), F(*)
      Integer templateR(*), templateC(*)

C Local variables
      Integer   ANI_Dnull
      External  ANI_Dnull

      Real*8   XYP(3, 4)
C ======================================================================
      Do i = 1, 3
         XYP(i, 1) = XY1(i)
         XYP(i, 2) = XY2(i)
         XYP(i, 3) = XY3(i)
         XYP(i, 4) = XY4(i)
      End do

c ... size of the elemental problem (4 pressures)
      nRow = 4 
      nCol = 4

c ... set up templates 
      Do i = 1, 4
         templateR(i)      = Vdof   
      End do

      Do k = 1, nRow
         templateC(k) = templateR(k)
      End do

c ... compute the mass matrix (M)
      label = lbE

c     A(1:4,1:4) is local mass matrix 
      Call fem3Dtet(XY1, XY2, XY3, XY4,
     &              IDEN, FEM_P1, IDEN, FEM_P1,
     &              label, ANI_Dnull, DATA, iSYS, 2,
     &              LDA, A, ir, ic)
      

      Return
      End


