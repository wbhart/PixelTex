
; OpenGL programming example

format PE GUI 4.0
entry start

include '%fasminc%\win32a.inc'

include 'opengl.inc'

section '.data' data readable writeable

  _title db 'Sphere',0
  _class db 'OPENGL',0

  theta GLfloat 0.6

  width = word 1280
  height = word 1024
  widthx dd 1280
  heighty dd 1024
  bits = word 32

  two dd 2.0f

  rot	  dd 0.0f
  rotamt  dd 1.0f

  randseed dd 2036471857
  randscale dd 1.5258789E-5

  dncount dd 2000
  dnscale dd 0.0005
  dnscale2 dd 0.05

  groupID db 'RIFF'
  gap dd  ?
  riffType db 'WAVE'
  FMTchunkID db 'fmt '
  FMTchunksize dd 16
  wFormatTag dw 1
  wChannels dw 1
  dwSamplesPerSec dd 44100
  dwAvgBytesPerSec dd 88200
  wBlockAlign dw 2
  wBitsPerSample dw 16
  DATAchunkID db 'data'
  DATAchunkSize dd 8448000

  wavemult dd 16383.0
  volume   dd 0.4

  fontname db 'Arial',0

  coords   dw 0,0
  comma    db ','
  ycoords  dw 0,0

  glu1 dq 45.0f
  glu2 dq 1.25f
  glu3 dq 0.1f
  glu4 dq 100.0f

  clear1 dq 0.0f
  clear2 dq 0.5f

  depthf dq 1.0f

  fill = word 0

section '.data2' data readable writeable

  waveheader rb 36
  wavechunk rb 8
  wavedata rb 8448000

  WindowRect RECT

  active dd ?

  randomval dd ?

  rnddscale dd ?
  rnddval dd ?

  intstore dd ?

  msg MSG
  wc WNDCLASS
  rc RECT
  ps PAINTSTRUCT
  pfd PIXELFORMATDESCRIPTOR
  dmScreenSettings DEVMODE
  font dd ?

  circcoord dd ?

  ratio GLdouble ?

  texname GLuint ?

  bmpptr dd ?

  hinstance dd ?
  hwnd dd ?
  hdc dd ?
  hrc dd ?
  base dd ?

section '.code' code readable executable

  start:
	invoke	GetModuleHandle,NULL
	mov	[hinstance],eax

	invoke	LoadIcon,NULL,IDI_WINLOGO
	mov	[wc.hIcon],eax

	invoke	LoadCursor,NULL,IDC_ARROW
	mov	[wc.hCursor],eax

	mov	[wc.style],CS_HREDRAW+CS_VREDRAW+CS_OWNDC
	mov	[wc.lpfnWndProc],WindowProc
	mov	[wc.cbClsExtra],0
	mov	[wc.cbWndExtra],0
	mov	eax,[hinstance]
	mov	[wc.hInstance],eax
	mov	[wc.hbrBackground],NULL
	mov	dword [wc.lpszMenuName],NULL
	mov	dword [wc.lpszClassName],_class
	invoke	RegisterClass,wc

	mov	edi,dmScreenSettings
	mov	ecx,sizeof.DEVMODE
	xor	ax,ax
	rep	stosb

	mov	[dmScreenSettings.dmSize],sizeof.DEVMODE
	mov	[dmScreenSettings.dmPelsWidth],width
	mov	[dmScreenSettings.dmPelsHeight],height
	mov	[dmScreenSettings.dmBitsPerPel],bits
	mov	[dmScreenSettings.dmFields],DM_BITSPERPEL+DM_PELSWIDTH+DM_PELSHEIGHT
	invoke	ChangeDisplaySettings,dmScreenSettings,CDS_FULLSCREEN

	mov	[WindowRect.left],0
	mov	[WindowRect.right],width
	mov	[WindowRect.top],0
	mov	[WindowRect.bottom],height
	invoke	AdjustWindowRectEx,WindowRect,WS_POPUP,FALSE,WS_EX_APPWINDOW

	invoke	ShowCursor,TRUE
	invoke	CreateWindowEx,WS_EX_APPWINDOW,_class,_title,WS_POPUP+WS_CLIPCHILDREN+WS_CLIPSIBLINGS,0,0,width,height,NULL,NULL,[hinstance],NULL
	mov	[hwnd],eax

  msg_loop:
	invoke	InvalidateRect,[hwnd],NULL,FALSE
	invoke	GetMessage,msg,NULL,0,0
	or	eax,eax
	jz	end_loop
	invoke	TranslateMessage,msg
	invoke	DispatchMessage,msg
	jmp	msg_loop

  end_loop:
	invoke	ExitProcess,[msg.wParam]

proc WindowProc, hwnd,wmsg,wparam,lparam
	push	ebx esi edi
	cmp	[wmsg],WM_MOUSEMOVE
	je	wmmousemove
	cmp	[wmsg],WM_CREATE
	je	wmcreate
	cmp	[wmsg],WM_SIZE
	je	wmsize
	cmp	[wmsg],WM_ACTIVATEAPP
	je	wmactivateapp
	cmp	[wmsg],WM_PAINT
	je	wmpaint
	cmp	[wmsg],WM_KEYDOWN
	je	wmkeydown
	cmp	[wmsg],WM_DESTROY
	je	wmdestroy
  defwndproc:
	invoke	DefWindowProc,[hwnd],[wmsg],[wparam],[lparam]
	jmp	finish
  wmmousemove:
	push bx
	mov	eax,[lparam]
	push	eax
	pop	ax
	call	bin2dec
	mov	bh,ah
	xor	ah,ah
	mov	ah,al
	and	ah,0fh
	shr	al,4
	add	ax,03030h
	mov	[coords+2],ax
	mov	al,bh
	xor	ah,ah
	mov	ah,al
	and	ah,0fh
	shr	al,4
	add	ax,03030h
	mov	[coords],ax
	pop	ax
	call	bin2dec
	mov	bh,ah
	xor	ah,ah
	mov	ah,al
	and	ah,0fh
	shr	al,4
	add	ax,03030h
	mov	[coords+7],ax
	mov	al,bh
	xor	ah,ah
	mov	ah,al
	and	ah,0fh
	shr	al,4
	add	ax,03030h
	mov	[coords+5],ax
	pop bx
	jmp	finish
  wmcreate:
	invoke	GetDC,[hwnd]
	mov	[hdc],eax
	mov	edi,pfd
	mov	ecx,sizeof.PIXELFORMATDESCRIPTOR shr 2
	xor	eax,eax
	rep	stosd
	mov	[pfd.nSize],sizeof.PIXELFORMATDESCRIPTOR
	mov	[pfd.nVersion],1
	mov	[pfd.dwFlags],PFD_SUPPORT_OPENGL+PFD_DOUBLEBUFFER+PFD_DRAW_TO_WINDOW
	mov	[pfd.iPixelType],PFD_TYPE_RGBA
	mov	[pfd.dwLayerMask],PFD_MAIN_PLANE
	mov	[pfd.cColorBits],16
	mov	[pfd.cDepthBits],16
	mov	[pfd.cAccumBits],0
	mov	[pfd.cStencilBits],0
	invoke	ChoosePixelFormat,[hdc],pfd
	invoke	SetPixelFormat,[hdc],eax,pfd
	invoke	wglCreateContext,[hdc]
	mov	[hrc],eax
	invoke	wglMakeCurrent,[hdc],[hrc]

	invoke	ShowWindow,[hwnd],SW_SHOW
	invoke	SetForegroundWindow,[hwnd]
	invoke	SetFocus,[hwnd]

	invoke	glViewport,0,0,widthx,heighty
	invoke	glMatrixMode,GL_PROJECTION
	invoke	glLoadIdentity
	push	dword [glu4+4]
	push	dword [glu4]
	push	dword [glu3+4]
	push	dword [glu3]
	push	dword [glu2+4]
	push	dword [glu2]
	push	dword [glu1+4]
	push	dword [glu1]
	mov	eax,eax
	mov	ebx,ebx
	invoke	gluPerspective
	invoke	glMatrixMode,GL_MODELVIEW
	invoke	glLoadIdentity

	invoke	glGenTextures,1,ptr texname
	invoke	glBindTexture,GL_TEXTURE_2D,[texname]

	invoke GlobalAlloc, GPTR, 49153
	inc eax

	mov dword [bmpptr],eax

	mov esi, eax
	mov bx, 1000
  dotloop:
	mov edx, 16383
	call rndd
	mov dx, 3
	mul dx
	mov edi, eax
	mov edx, 4
	call rndd
	mov cl, al
	add cl, 5
	dec cl
	mov edx, 00000007Ch
	call rndd
	mov dl, al
	shl ax, 8
	mov al, dl
	shl eax, 8
	mov al, dl
	shl eax,8
	add eax, 0034C5F00h
	call CircleDraw
	dec bx
	jnz dotloop

	mov eax, [bmpptr]

	invoke	gluBuild2DMipmaps,GL_TEXTURE_2D,3,128,128,GL_RGB,GL_UNSIGNED_BYTE,eax
	invoke	glTexParameteri,GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR
	invoke	glTexParameteri,GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_NEAREST
	invoke	glTexGeni,GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP
	invoke	glTexGeni,GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP
	invoke	glEnable,GL_TEXTURE_GEN_S
	invoke	glEnable,GL_TEXTURE_GEN_T

	invoke	glGenLists,256
	invoke	CreateFont,-12,0,30,0,FW_THIN,FALSE,FALSE,FALSE,ANSI_CHARSET,OUT_TT_PRECIS,CLIP_DEFAULT_PRECIS,ANTIALIASED_QUALITY,FF_DONTCARE+DEFAULT_PITCH,fontname
	mov	[font],eax
	invoke	SelectObject,[hdc],[font]
	invoke	wglUseFontOutlinesA,[hdc],0,255,1000,0.001f,0.5f,WGL_FONT_POLYGONS,NULL

	invoke	glShadeModel,GL_SMOOTH
	push	dword [clear2+4]
	push	dword [clear2]
	push	dword [clear1+4]
	push	dword [clear1]
	push	dword [clear1+4]
	push	dword [clear1]
	push	dword [clear1+4]
	push	dword [clear1]
	mov	eax,eax
	mov	ecx,ecx
	invoke	glClearColor
	push	dword [depthf+4]
	push	dword [depthf]
	mov	eax,eax
	mov	ebx,ebx
	invoke	glClearDepth
	invoke	glEnable,GL_DEPTH_TEST
	invoke	glDepthFunc,GL_LEQUAL
	invoke	glHint,GL_PERSPECTIVE_CORRECTION_HINT,GL_NICEST
	invoke	glEnable,GL_LIGHT0
	invoke	glEnable,GL_LIGHTING
	invoke	glEnable,GL_TEXTURE_2D
	invoke	glBindTexture,GL_TEXTURE_2D,[texname]

	mov edi, waveheader
	mov esi, groupID
	mov ecx, 02Ch
	rep movsb

	invoke GlobalAlloc, GMEM_FIXED+GMEM_ZEROINIT, 16896000
	mov esi, eax
	mov ecx, 220
  tickloop:
	call decaynoise
	add esi, 11400h
	loop tickloop

	mov esi, eax
	mov edi, wavedata
	mov ecx, 4224000

  volumeloop:
	fld dword [esi]
	fmul [wavemult]
	fistp dword [intstore]
	mov eax, [intstore]
	test eax, eax
	jz endloop
	cdq

	fld dword [volume]
	fld dword [esi]
	fabs
	fyl2x
	fld st0
	frndint
	fxch
	fsub st0, st1
	f2xm1
	fld1
	faddp
	fscale
	fstp st1

	fild [intstore]
	fabs
	fistp dword [intstore]
	idiv dword [intstore]
	mov [intstore], eax
	fild [intstore]
	fmulp
	fmul [wavemult]
	fistp dword [intstore]
	pxor mm7, mm7
	movd mm0, dword [intstore]
	packssdw mm0, mm7
	movd dword [intstore], mm0
	emms
	mov ax, word [intstore]
  endloop:
	mov [edi], ax

	inc edi
	inc edi
	add esi, 4
	dec ecx
	cmp ecx, 0
	jne volumeloop

	invoke SndPlaySoundA, waveheader, 7

	xor	eax,eax
	jmp	finish
  wmsize:
	invoke	GetClientRect,[hwnd],rc
	invoke	glViewport,0,0,[rc.right],[rc.bottom]
	invoke	InvalidateRect,[hwnd],NULL,FALSE
	xor	eax,eax
	jmp	finish
  wmactivateapp:
	push	[wmsg]
	pop	[active]
	xor	eax,eax
	jmp	finish
  wmpaint:
	invoke	glClear,GL_COLOR_BUFFER_BIT+GL_DEPTH_BUFFER_BIT
	invoke	glLoadIdentity

	invoke	glTranslatef,-2.0f,0.0f,-6.0f
	invoke	glRotatef,[rot],1.0f,0.0f,0.0f
	invoke	glPushAttrib,GL_LIST_BIT
	invoke	glListBase,1000
	invoke	glCallLists,9,GL_UNSIGNED_BYTE,coords
	invoke	glPopAttrib

	;invoke glRasterPos3i,0,0,0
	;mov eax,[bmpptr]
	;invoke glDrawPixels,128,128,GL_RGB,GL_UNSIGNED_BYTE,eax

	invoke	SwapBuffers,[hdc]
	fld	[rot]
	fadd	dword [rotamt]
	fstp	dword [rot]

	xor	eax,eax
	jmp	finish
  wmkeydown:
	cmp	[wparam],VK_ESCAPE
	jne	defwndproc
  wmdestroy:
	invoke	wglMakeCurrent,0,0
	invoke	wglDeleteContext,[hrc]
	invoke	ReleaseDC,[hwnd],[hdc]
	invoke	PostQuitMessage,0
	xor	eax,eax
  finish:
	pop	edi esi ebx
	return
endp

proc random
	push eax
	mov eax, 214013
	imul dword [randseed]
	add eax, -1013045760
	ror eax, 0Bh
	mov [randseed],eax
	shr eax, 010h
	mov [randomval], eax
	fild dword [randomval]
	fmul dword [randscale]
	pop eax
	ret
endp

proc rndd
	mov [rnddscale],edx
	fild dword [rnddscale]
	call random
	fmulp
	frndint
	fistp dword [rnddval]
	mov eax, [rnddval]
	ret
endp

proc decaynoise
	push esi
	test cl,01h
	je lowerskip
	mov [dncount], 2000
	jmp dnloop
  lowerskip:
	mov [dncount], 1000
  dnloop:
	call random
	fild dword [dncount]
	test cl, 01h
	jne  skipmult
	fmul dword [two]
    skipmult:
	fmul dword [dnscale]
	fmulp
	dec [dncount]
	fmul dword [dnscale2]
	fadd dword [esi]
	fstp dword [esi]
	add esi, 4
	cmp [dncount],0
	jg dnloop
	pop esi
	ret
endp

proc bin2dec ;converts a bin # in ax to decimal in ax
	push	bx
	xor	bx,bx
  loop100:
	cmp	ax,100d
	jb	less100
	inc	bh
	sub	ax,100d
	jmp	loop100
  less100:
	mov	bl,al
	and	al,07h
	test	bl,08h
	jz	dig3
	add	al,08h
	daa
  dig3:
	test	bl,010h
	jz	dig4
	add	al,016h
	daa
  dig4:
	test	bl,020h
	jz	dig5
	add	al,032h
	daa
  dig5:
	test	bl,040h
	jz	done100
	add	al,064h
	daa
  done100:

	mov	bl,al
	mov	al,bh

	and	al,07h
	test	bh,08h
	jz	dig6
	add	al,8
	daa
  dig6:
	test	bh,010h
	jz	dig7
	add	al,016h
	daa
  dig7:
	test	bh,020h
	jz	dig8
	add	al,032h
	daa
  dig8:
	test	bh,040h
	jz	done10000
	add	al,064h
	daa
done10000:
	mov ah,al
	mov al,bl
	pop bx
ret
endp

proc circlepoints ;esi=strt,edi=3*128*x+3*y,ch=x1,cl=y1,eax=clr
	push cx
	push bx
  lineloop:
	xor al, al

  loopfour:
	xor ebx, ebx
	mov bl, cl
	shl bx, 1
	add bl, cl
	adc bh, 0
	test al, 02h
	jz plus1
	neg bx
  plus1:
	mov dl, ch
	xchg ax, dx
	cbw
	xchg ax, dx
	shl bx, 6
	add bx, dx
	shl bx, 1
	add bx, dx
	neg ch
	xchg eax, ebx
	cwde
	xchg eax, ebx
	add ebx, edi
	push edi
	mov edi, esi
	add edi, 49149
	add ebx, esi
	cmp ebx, edi
	jna ptna
	sub ebx, 49152
  ptna:
	cmp ebx, esi
	jnb ptok
	add ebx, 49152
  ptok:
	pop edi
	push ax
	mov al,[ebx-1]
	mov [ebx-1],eax
	pop ax

	inc al
	test al, 03h
	jnz loopfour

	xchg cl, ch
	test al, 08h
	jz loopfour

	dec cl
	cmp cl, 0FFh
	jne lineloop

	pop bx
	pop cx
	ret
endp

proc CircleDraw ;esi=strt,edi=3*128*x+3*y, cl=radius,eax=clr
	push cx
	push bx
	xor ch, ch ;ch = x1, cl = y1
	xor bx, bx ;bx = p
	mov bl, cl
	shl bx, 1
	neg bx
	add bx, 3
  circleloop:
	call circlepoints
	push ax
	cmp bx, 08000h
	ja plz
	xor ax, ax
	mov al, cl
	sub al, ch
	shl ax, 2
	sub bx, ax
	add bx, 10
	dec cl
	jmp circont
  plz:
	xor ax,ax
	mov al, ch
	shl ax, 2
	add bx, ax
	add bx, 6
  circont:
	inc ch
	pop ax
	cmp ch, cl
	jbe circleloop
	pop bx
	pop cx
	ret
endp

section '.idata' import data readable writeable

  library kernel,'KERNEL32.DLL',\
	  user,'USER32.DLL',\
	  gdi,'GDI32.DLL',\
	  opengl,'OPENGL32.DLL',\
	  glu,'GLU32.DLL',\
	  winmm,'WINMM.DLL'

  import kernel,\
	 GetModuleHandle,'GetModuleHandleA',\
	 ExitProcess,'ExitProcess',\
	 CreateFile,'CreateFileA',\
	 GetFileSize,'GetFileSize',\
	 GlobalAlloc,'GlobalAlloc',\
	 ReadFile,'ReadFile',\
	 CloseHandle,'CloseHandle'

  import user,\
	 AdjustWindowRectEx,'AdjustWindowRectEx',\
	 RegisterClass,'RegisterClassA',\
	 CreateWindowEx,'CreateWindowExA',\
	 DefWindowProc,'DefWindowProcA',\
	 GetMessage,'GetMessageA',\
	 TranslateMessage,'TranslateMessage',\
	 DispatchMessage,'DispatchMessageA',\
	 LoadCursor,'LoadCursorA',\
	 LoadIcon,'LoadIconA',\
	 GetClientRect,'GetClientRect',\
	 InvalidateRect,'InvalidateRect',\
	 GetDC,'GetDC',\
	 ReleaseDC,'ReleaseDC',\
	 PostQuitMessage,'PostQuitMessage',\
	 ChangeDisplaySettings,'ChangeDisplaySettingsA',\
	 ShowWindow,'ShowWindow',\
	 SetForegroundWindow,'SetForegroundWindow',\
	 SetFocus,'SetFocus',\
	 ShowCursor,'ShowCursor',\
	 MessageBox,'MessageBoxA'

  import gdi,\
	 ChoosePixelFormat,'ChoosePixelFormat',\
	 SetPixelFormat,'SetPixelFormat',\
	 SwapBuffers,'SwapBuffers',\
	 CreateFont,'CreateFontA',\
	 SelectObject,'SelectObject'

  import winmm,\
	 SndPlaySoundA,'sndPlaySoundA'

  import opengl,\
	 glAccum,'glAccum',\
	 glAlphaFunc,'glAlphaFunc',\
	 glAreTexturesResident,'glAreTexturesResident',\
	 glArrayElement,'glArrayElement',\
	 glBegin,'glBegin',\
	 glBindTexture,'glBindTexture',\
	 glBitmap,'glBitmap',\
	 glBlendFunc,'glBlendFunc',\
	 glCallList,'glCallList',\
	 glCallLists,'glCallLists',\
	 glClear,'glClear',\
	 glClearAccum,'glClearAccum',\
	 glClearColor,'glClearColor',\
	 glClearDepth,'glClearDepth',\
	 glClearIndex,'glClearIndex',\
	 glClearStencil,'glClearStencil',\
	 glClipPlane,'glClipPlane',\
	 glColor3b,'glColor3b',\
	 glColor3bv,'glColor3bv',\
	 glColor3d,'glColor3d',\
	 glColor3dv,'glColor3dv',\
	 glColor3f,'glColor3f',\
	 glColor3fv,'glColor3fv',\
	 glColor3i,'glColor3i',\
	 glColor3iv,'glColor3iv',\
	 glColor3s,'glColor3s',\
	 glColor3sv,'glColor3sv',\
	 glColor3ub,'glColor3ub',\
	 glColor3ubv,'glColor3ubv',\
	 glColor3ui,'glColor3ui',\
	 glColor3uiv,'glColor3uiv',\
	 glColor3us,'glColor3us',\
	 glColor3usv,'glColor3usv',\
	 glColor4b,'glColor4b',\
	 glColor4bv,'glColor4bv',\
	 glColor4d,'glColor4d',\
	 glColor4dv,'glColor4dv',\
	 glColor4f,'glColor4f',\
	 glColor4fv,'glColor4fv',\
	 glColor4i,'glColor4i',\
	 glColor4iv,'glColor4iv',\
	 glColor4s,'glColor4s',\
	 glColor4sv,'glColor4sv',\
	 glColor4ub,'glColor4ub',\
	 glColor4ubv,'glColor4ubv',\
	 glColor4ui,'glColor4ui',\
	 glColor4uiv,'glColor4uiv',\
	 glColor4us,'glColor4us',\
	 glColor4usv,'glColor4usv',\
	 glColorMask,'glColorMask',\
	 glColorMaterial,'glColorMaterial',\
	 glColorPointer,'glColorPointer',\
	 glCopyPixels,'glCopyPixels',\
	 glCopyTexImage1D,'glCopyTexImage1D',\
	 glCopyTexImage2D,'glCopyTexImage2D',\
	 glCopyTexSubImage1D,'glCopyTexSubImage1D',\
	 glCopyTexSubImage2D,'glCopyTexSubImage2D',\
	 glCullFace,'glCullFace',\
	 glDeleteLists,'glDeleteLists',\
	 glDeleteTextures,'glDeleteTextures',\
	 glDepthFunc,'glDepthFunc',\
	 glDepthMask,'glDepthMask',\
	 glDepthRange,'glDepthRange',\
	 glDisable,'glDisable',\
	 glDisableClientState,'glDisableClientState',\
	 glDrawArrays,'glDrawArrays',\
	 glDrawBuffer,'glDrawBuffer',\
	 glDrawElements,'glDrawElements',\
	 glDrawPixels,'glDrawPixels',\
	 glEdgeFlag,'glEdgeFlag',\
	 glEdgeFlagPointer,'glEdgeFlagPointer',\
	 glEdgeFlagv,'glEdgeFlagv',\
	 glEnable,'glEnable',\
	 glEnableClientState,'glEnableClientState',\
	 glEnd,'glEnd',\
	 glEndList,'glEndList',\
	 glEvalCoord1d,'glEvalCoord1d',\
	 glEvalCoord1dv,'glEvalCoord1dv',\
	 glEvalCoord1f,'glEvalCoord1f',\
	 glEvalCoord1fv,'glEvalCoord1fv',\
	 glEvalCoord2d,'glEvalCoord2d',\
	 glEvalCoord2dv,'glEvalCoord2dv',\
	 glEvalCoord2f,'glEvalCoord2f',\
	 glEvalCoord2fv,'glEvalCoord2fv',\
	 glEvalMesh1,'glEvalMesh1',\
	 glEvalMesh2,'glEvalMesh2',\
	 glEvalPoint1,'glEvalPoint1',\
	 glEvalPoint2,'glEvalPoint2',\
	 glFeedbackBuffer,'glFeedbackBuffer',\
	 glFinish,'glFinish',\
	 glFlush,'glFlush',\
	 glFogf,'glFogf',\
	 glFogfv,'glFogfv',\
	 glFogi,'glFogi',\
	 glFogiv,'glFogiv',\
	 glFrontFace,'glFrontFace',\
	 glFrustum,'glFrustum',\
	 glGenLists,'glGenLists',\
	 glGenTextures,'glGenTextures',\
	 glGetBooleanv,'glGetBooleanv',\
	 glGetClipPlane,'glGetClipPlane',\
	 glGetDoublev,'glGetDoublev',\
	 glGetError,'glGetError',\
	 glGetFloatv,'glGetFloatv',\
	 glGetIntegerv,'glGetIntegerv',\
	 glGetLightfv,'glGetLightfv',\
	 glGetLightiv,'glGetLightiv',\
	 glGetMapdv,'glGetMapdv',\
	 glGetMapfv,'glGetMapfv',\
	 glGetMapiv,'glGetMapiv',\
	 glGetMaterialfv,'glGetMaterialfv',\
	 glGetMaterialiv,'glGetMaterialiv',\
	 glGetPixelMapfv,'glGetPixelMapfv',\
	 glGetPixelMapuiv,'glGetPixelMapuiv',\
	 glGetPixelMapusv,'glGetPixelMapusv',\
	 glGetPointerv,'glGetPointerv',\
	 glGetPolygonStipple,'glGetPolygonStipple',\
	 glGetString,'glGetString',\
	 glGetTexEnvfv,'glGetTexEnvfv',\
	 glGetTexEnviv,'glGetTexEnviv',\
	 glGetTexGendv,'glGetTexGendv',\
	 glGetTexGenfv,'glGetTexGenfv',\
	 glGetTexGeniv,'glGetTexGeniv',\
	 glGetTexImage,'glGetTexImage',\
	 glGetTexLevelParameterfv,'glGetTexLevelParameterfv',\
	 glGetTexLevelParameteriv,'glGetTexLevelParameteriv',\
	 glGetTexParameterfv,'glGetTexParameterfv',\
	 glGetTexParameteriv,'glGetTexParameteriv',\
	 glHint,'glHint',\
	 glIndexMask,'glIndexMask',\
	 glIndexPointer,'glIndexPointer',\
	 glIndexd,'glIndexd',\
	 glIndexdv,'glIndexdv',\
	 glIndexf,'glIndexf',\
	 glIndexfv,'glIndexfv',\
	 glIndexi,'glIndexi',\
	 glIndexiv,'glIndexiv',\
	 glIndexs,'glIndexs',\
	 glIndexsv,'glIndexsv',\
	 glIndexub,'glIndexub',\
	 glIndexubv,'glIndexubv',\
	 glInitNames,'glInitNames',\
	 glInterleavedArrays,'glInterleavedArrays',\
	 glIsEnabled,'glIsEnabled',\
	 glIsList,'glIsList',\
	 glIsTexture,'glIsTexture',\
	 glLightModelf,'glLightModelf',\
	 glLightModelfv,'glLightModelfv',\
	 glLightModeli,'glLightModeli',\
	 glLightModeliv,'glLightModeliv',\
	 glLightf,'glLightf',\
	 glLightfv,'glLightfv',\
	 glLighti,'glLighti',\
	 glLightiv,'glLightiv',\
	 glLineStipple,'glLineStipple',\
	 glLineWidth,'glLineWidth',\
	 glListBase,'glListBase',\
	 glLoadIdentity,'glLoadIdentity',\
	 glLoadMatrixd,'glLoadMatrixd',\
	 glLoadMatrixf,'glLoadMatrixf',\
	 glLoadName,'glLoadName',\
	 glLogicOp,'glLogicOp',\
	 glMap1d,'glMap1d',\
	 glMap1f,'glMap1f',\
	 glMap2d,'glMap2d',\
	 glMap2f,'glMap2f',\
	 glMapGrid1d,'glMapGrid1d',\
	 glMapGrid1f,'glMapGrid1f',\
	 glMapGrid2d,'glMapGrid2d',\
	 glMapGrid2f,'glMapGrid2f',\
	 glMaterialf,'glMaterialf',\
	 glMaterialfv,'glMaterialfv',\
	 glMateriali,'glMateriali',\
	 glMaterialiv,'glMaterialiv',\
	 glMatrixMode,'glMatrixMode',\
	 glMultMatrixd,'glMultMatrixd',\
	 glMultMatrixf,'glMultMatrixf',\
	 glNewList,'glNewList',\
	 glNormal3b,'glNormal3b',\
	 glNormal3bv,'glNormal3bv',\
	 glNormal3d,'glNormal3d',\
	 glNormal3dv,'glNormal3dv',\
	 glNormal3f,'glNormal3f',\
	 glNormal3fv,'glNormal3fv',\
	 glNormal3i,'glNormal3i',\
	 glNormal3iv,'glNormal3iv',\
	 glNormal3s,'glNormal3s',\
	 glNormal3sv,'glNormal3sv',\
	 glNormalPointer,'glNormalPointer',\
	 glOrtho,'glOrtho',\
	 glPassThrough,'glPassThrough',\
	 glPixelMapfv,'glPixelMapfv',\
	 glPixelMapuiv,'glPixelMapuiv',\
	 glPixelMapusv,'glPixelMapusv',\
	 glPixelStoref,'glPixelStoref',\
	 glPixelStorei,'glPixelStorei',\
	 glPixelTransferf,'glPixelTransferf',\
	 glPixelTransferi,'glPixelTransferi',\
	 glPixelZoom,'glPixelZoom',\
	 glPointSize,'glPointSize',\
	 glPolygonMode,'glPolygonMode',\
	 glPolygonOffset,'glPolygonOffset',\
	 glPolygonStipple,'glPolygonStipple',\
	 glPopAttrib,'glPopAttrib',\
	 glPopClientAttrib,'glPopClientAttrib',\
	 glPopMatrix,'glPopMatrix',\
	 glPopName,'glPopName',\
	 glPrioritizeTextures,'glPrioritizeTextures',\
	 glPushAttrib,'glPushAttrib',\
	 glPushClientAttrib,'glPushClientAttrib',\
	 glPushMatrix,'glPushMatrix',\
	 glPushName,'glPushName',\
	 glRasterPos2d,'glRasterPos2d',\
	 glRasterPos2dv,'glRasterPos2dv',\
	 glRasterPos2f,'glRasterPos2f',\
	 glRasterPos2fv,'glRasterPos2fv',\
	 glRasterPos2i,'glRasterPos2i',\
	 glRasterPos2iv,'glRasterPos2iv',\
	 glRasterPos2s,'glRasterPos2s',\
	 glRasterPos2sv,'glRasterPos2sv',\
	 glRasterPos3d,'glRasterPos3d',\
	 glRasterPos3dv,'glRasterPos3dv',\
	 glRasterPos3f,'glRasterPos3f',\
	 glRasterPos3fv,'glRasterPos3fv',\
	 glRasterPos3i,'glRasterPos3i',\
	 glRasterPos3iv,'glRasterPos3iv',\
	 glRasterPos3s,'glRasterPos3s',\
	 glRasterPos3sv,'glRasterPos3sv',\
	 glRasterPos4d,'glRasterPos4d',\
	 glRasterPos4dv,'glRasterPos4dv',\
	 glRasterPos4f,'glRasterPos4f',\
	 glRasterPos4fv,'glRasterPos4fv',\
	 glRasterPos4i,'glRasterPos4i',\
	 glRasterPos4iv,'glRasterPos4iv',\
	 glRasterPos4s,'glRasterPos4s',\
	 glRasterPos4sv,'glRasterPos4sv',\
	 glReadPixels,'glReadPixels',\
	 glReadBuffer,'glReadBuffer',\
	 glRectd,'glRectd',\
	 glRectdv,'glRectdv',\
	 glRectf,'glRectf',\
	 glRectfv,'glRectfv',\
	 glRecti,'glRecti',\
	 glRectiv,'glRectiv',\
	 glRects,'glRects',\
	 glRectsv,'glRectsv',\
	 glRenderMode,'glRenderMode',\
	 glRotated,'glRotated',\
	 glRotatef,'glRotatef',\
	 glScaled,'glScaled',\
	 glScalef,'glScalef',\
	 glScissor,'glScissor',\
	 glSelectBuffer,'glSelectBuffer',\
	 glShadeModel,'glShadeModel',\
	 glStencilFunc,'glStencilFunc',\
	 glStencilMask,'glStencilMask',\
	 glStencilOp,'glStencilOp',\
	 glTexCoord1d,'glTexCoord1d',\
	 glTexCoord1dv,'glTexCoord1dv',\
	 glTexCoord1f,'glTexCoord1f',\
	 glTexCoord1fv,'glTexCoord1fv',\
	 glTexCoord1i,'glTexCoord1i',\
	 glTexCoord1iv,'glTexCoord1iv',\
	 glTexCoord1s,'glTexCoord1s',\
	 glTexCoord1sv,'glTexCoord1sv',\
	 glTexCoord2d,'glTexCoord2d',\
	 glTexCoord2dv,'glTexCoord2dv',\
	 glTexCoord2f,'glTexCoord2f',\
	 glTexCoord2fv,'glTexCoord2fv',\
	 glTexCoord2i,'glTexCoord2i',\
	 glTexCoord2iv,'glTexCoord2iv',\
	 glTexCoord2s,'glTexCoord2s',\
	 glTexCoord2sv,'glTexCoord2sv',\
	 glTexCoord3d,'glTexCoord3d',\
	 glTexCoord3dv,'glTexCoord3dv',\
	 glTexCoord3f,'glTexCoord3f',\
	 glTexCoord3fv,'glTexCoord3fv',\
	 glTexCoord3i,'glTexCoord3i',\
	 glTexCoord3iv,'glTexCoord3iv',\
	 glTexCoord3s,'glTexCoord3s',\
	 glTexCoord3sv,'glTexCoord3sv',\
	 glTexCoord4d,'glTexCoord4d',\
	 glTexCoord4dv,'glTexCoord4dv',\
	 glTexCoord4f,'glTexCoord4f',\
	 glTexCoord4fv,'glTexCoord4fv',\
	 glTexCoord4i,'glTexCoord4i',\
	 glTexCoord4iv,'glTexCoord4iv',\
	 glTexCoord4s,'glTexCoord4s',\
	 glTexCoord4sv,'glTexCoord4sv',\
	 glTexCoordPointer,'glTexCoordPointer',\
	 glTexEnvf,'glTexEnvf',\
	 glTexEnvfv,'glTexEnvfv',\
	 glTexEnvi,'glTexEnvi',\
	 glTexEnviv,'glTexEnviv',\
	 glTexGend,'glTexGend',\
	 glTexGendv,'glTexGendv',\
	 glTexGenf,'glTexGenf',\
	 glTexGenfv,'glTexGenfv',\
	 glTexGeni,'glTexGeni',\
	 glTexGeniv,'glTexGeniv',\
	 glTexImage1D,'glTexImage1D',\
	 glTexImage2D,'glTexImage2D',\
	 glTexParameterf,'glTexParameterf',\
	 glTexParameterfv,'glTexParameterfv',\
	 glTexParameteri,'glTexParameteri',\
	 glTexParameteriv,'glTexParameteriv',\
	 glTexSubImage1D,'glTexSubImage1D',\
	 glTexSubImage2D,'glTexSubImage2D',\
	 glTranslated,'glTranslated',\
	 glTranslatef,'glTranslatef',\
	 glVertex2d,'glVertex2d',\
	 glVertex2dv,'glVertex2dv',\
	 glVertex2f,'glVertex2f',\
	 glVertex2fv,'glVertex2fv',\
	 glVertex2i,'glVertex2i',\
	 glVertex2iv,'glVertex2iv',\
	 glVertex2s,'glVertex2s',\
	 glVertex2sv,'glVertex2sv',\
	 glVertex3d,'glVertex3d',\
	 glVertex3dv,'glVertex3dv',\
	 glVertex3f,'glVertex3f',\
	 glVertex3fv,'glVertex3fv',\
	 glVertex3i,'glVertex3i',\
	 glVertex3iv,'glVertex3iv',\
	 glVertex3s,'glVertex3s',\
	 glVertex3sv,'glVertex3sv',\
	 glVertex4d,'glVertex4d',\
	 glVertex4dv,'glVertex4dv',\
	 glVertex4f,'glVertex4f',\
	 glVertex4fv,'glVertex4fv',\
	 glVertex4i,'glVertex4i',\
	 glVertex4iv,'glVertex4iv',\
	 glVertex4s,'glVertex4s',\
	 glVertex4sv,'glVertex4sv',\
	 glVertexPointer,'glVertexPointer',\
	 glViewport,'glViewport',\
	 wglGetProcAddress,'wglGetProcAddress',\
	 wglCopyContext,'wglCopyContext',\
	 wglCreateContext,'wglCreateContext',\
	 wglCreateLayerContext,'wglCreateLayerContext',\
	 wglDeleteContext,'wglDeleteContext',\
	 wglDescribeLayerPlane,'wglDescribeLayerPlane',\
	 wglGetCurrentContext,'wglGetCurrentContext',\
	 wglGetCurrentDC,'wglGetCurrentDC',\
	 wglGetLayerPaletteEntries,'wglGetLayerPaletteEntries',\
	 wglMakeCurrent,'wglMakeCurrent',\
	 wglRealizeLayerPalette,'wglRealizeLayerPalette',\
	 wglSetLayerPaletteEntries,'wglSetLayerPaletteEntries',\
	 wglShareLists,'wglShareLists',\
	 wglSwapLayerBuffers,'wglSwapLayerBuffers',\
	 wglSwapMultipleBuffers,'wglSwapMultipleBuffers',\
	 wglUseFontBitmapsA,'wglUseFontBitmapsA',\
	 wglUseFontOutlinesA,'wglUseFontOutlinesA',\
	 wglUseFontBitmapsW,'wglUseFontBitmapsW',\
	 wglUseFontOutlinesW,'wglUseFontOutlinesW',\
	 wglUseFontBitmaps,'wglUseFontBitmaps',\
	 wglUseFontOutlines,'wglUseFontOutlines',\
	 glDrawRangeElements,'glDrawRangeElements',\
	 glTexImage3D,'glTexImage3D',\
	 glBlendColor,'glBlendColor',\
	 glBlendEquation,'glBlendEquation',\
	 glColorSubTable,'glColorSubTable',\
	 glCopyColorSubTable,'glCopyColorSubTable',\
	 glColorTable,'glColorTable',\
	 glCopyColorTable,'glCopyColorTable',\
	 glColorTableParameteriv,'glColorTableParameteriv',\
	 glColorTableParameterfv,'glColorTableParameterfv',\
	 glGetColorTable,'glGetColorTable',\
	 glGetColorTableParameteriv,'glGetColorTableParameteriv',\
	 glGetColorTableParameterfv,'glGetColorTableParameterfv',\
	 glConvolutionFilter1D,'glConvolutionFilter1D',\
	 glConvolutionFilter2D,'glConvolutionFilter2D',\
	 glCopyConvolutionFilter1D,'glCopyConvolutionFilter1D',\
	 glCopyConvolutionFilter2D,'glCopyConvolutionFilter2D',\
	 glGetConvolutionFilter,'glGetConvolutionFilter',\
	 glSeparableFilter2D,'glSeparableFilter2D',\
	 glGetSeparableFilter,'glGetSeparableFilter',\
	 glConvolutionParameteri,'glConvolutionParameteri',\
	 glConvolutionParameteriv,'glConvolutionParameteriv',\
	 glConvolutionParameterf,'glConvolutionParameterf',\
	 glConvolutionParameterfv,'glConvolutionParameterfv',\
	 glGetConvolutionParameteriv,'glGetConvolutionParameteriv',\
	 glGetConvolutionParameterfv,'glGetConvolutionParameterfv',\
	 glHistogram,'glHistogram',\
	 glResetHistogram,'glResetHistogram',\
	 glGetHistogram,'glGetHistogram',\
	 glGetHistogramParameteriv,'glGetHistogramParameteriv',\
	 glGetHistogramParameterfv,'glGetHistogramParameterfv',\
	 glMinmax,'glMinmax',\
	 glResetMinmax,'glResetMinmax',\
	 glGetMinmax,'glGetMinmax',\
	 glGetMinmaxParameteriv,'glGetMinmaxParameteriv',\
	 glGetMinmaxParameterfv,'glGetMinmaxParameterfv'


  import glu,\
	 gluBeginCurve,'gluBeginCurve',\
	 gluBeginPolygon,'gluBeginPolygon',\
	 gluBeginSurface,'gluBeginSurface',\
	 gluBeginTrim,'gluBeginTrim',\
	 gluBuild1DMipmaps,'gluBuild1DMipmaps',\
	 gluBuild2DMipmaps,'gluBuild2DMipmaps',\
	 gluCylinder,'gluCylinder',\
	 gluDeleteNurbsRenderer,'gluDeleteNurbsRenderer',\
	 gluDeleteQuadric,'gluDeleteQuadric',\
	 gluDeleteTess,'gluDeleteTess',\
	 gluDisk,'gluDisk',\
	 gluEndCurve,'gluEndCurve',\
	 gluEndPolygon,'gluEndPolygon',\
	 gluEndSurface,'gluEndSurface',\
	 gluEndTrim,'gluEndTrim',\
	 gluErrorString,'gluErrorString',\
	 gluGetNurbsProperty,'gluGetNurbsProperty',\
	 gluGetString,'gluGetString',\
	 gluGetTessProperty,'gluGetTessProperty',\
	 gluLoadSamplingMatrices,'gluLoadSamplingMatrices',\
	 gluLookAt,'gluLookAt',\
	 gluNewNurbsRenderer,'gluNewNurbsRenderer',\
	 gluNewQuadric,'gluNewQuadric',\
	 gluNewTess,'gluNewTess',\
	 gluNextContour,'gluNextContour',\
	 gluNurbsCallback,'gluNurbsCallback',\
	 gluNurbsCurve,'gluNurbsCurve',\
	 gluNurbsProperty,'gluNurbsProperty',\
	 gluNurbsSurface,'gluNurbsSurface',\
	 gluOrtho2D,'gluOrtho2D',\
	 gluPartialDisk,'gluPartialDisk',\
	 gluPerspective,'gluPerspective',\
	 gluPickMatrix,'gluPickMatrix',\
	 gluProject,'gluProject',\
	 gluPwlCurve,'gluPwlCurve',\
	 gluQuadricCallback,'gluQuadricCallback',\
	 gluQuadricDrawStyle,'gluQuadricDrawStyle',\
	 gluQuadricNormals,'gluQuadricNormals',\
	 gluQuadricOrientation,'gluQuadricOrientation',\
	 gluQuadricTexture,'gluQuadricTexture',\
	 gluScaleImage,'gluScaleImage',\
	 gluSphere,'gluSphere',\
	 gluTessBeginContour,'gluTessBeginContour',\
	 gluTessBeginPolygon,'gluTessBeginPolygon',\
	 gluTessCallback,'gluTessCallback',\
	 gluTessEndContour,'gluTessEndContour',\
	 gluTessEndPolygon,'gluTessEndPolygon',\
	 gluTessNormal,'gluTessNormal',\
	 gluTessProperty,'gluTessProperty',\
	 gluTessVertex,'gluTessVertex',\
	 gluUnProject,'gluUnProject'

