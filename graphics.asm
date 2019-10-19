format MS COFF

include 'c:\flatasm\include\win32w.inc'
include 'c:\flatasm\include\opengl.inc'

public Flat as '_Flat'
public Point as '_Point'
public Rect as '_Rct'
public Plasma as '_Plasma'
public Clouds as '_Clouds'
public AddTextures as '_Add'
public Copy as '_CopyBitmap'
extrn __imp__glEnable@4
extrn __imp__glDisable@4
extrn __imp__glColor3ub@12
extrn __imp__glColor4ub@16
extrn __imp__glColor3f@12
extrn __imp__glPointSize@4
extrn __imp__glVertex2i@8
extrn __imp__glVertex2f@8
extrn __imp__glBegin@4
extrn __imp__glEnd@0
extrn __imp__glPixelZoom@8
extrn __imp__glCopyPixels@20
extrn __imp__glReadPixels@28
extrn __imp__glDrawPixels@20
extrn __imp__glRasterPos2i@8
extrn __imp__gluNewQuadric@0
extrn __imp__gluDisk@28
extrn __imp__glMaterialfv@12
extrn __imp__glTranslatef@12
extrn __imp__glLightModelfv@8
extrn __imp__glScalef@12
extrn __imp__glLoadIdentity@0
extrn __imp__glRecti@16
extrn __imp__glClearColor@16
extrn __imp__glClear@4
extrn __imp__glBlendFunc@8
extrn __imp__glColor4f@16
extrn __imp__glGenTextures@8
extrn __imp__glBindTexture@8
extrn __imp__glTexParameteri@12
extrn __imp__glTexImage2D@36
extrn __imp__glTexCoord2f@8
extrn __imp__glPixelStorei@8
extrn __imp__glTexEnvf@12
extrn __imp__glShadeModel@4

noisewidth EQU 32
nwlog EQU 5 ;log_2 noisewidth
noiseheight EQU 32
nhlog EQU 5 ;log_2 noiseheight

proc random ;returns with a random float between 0 and 1 on the cpu stack
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

proc fillnoise ; expects pointer to noisearray with dimensions noiseheight and noisewidth in esi
	push ebp
	mov ebp, esp
	push esi
	push ecx
	mov ecx, noisewidth*noiseheight
       noiseloop:
	call random
	fsub dword [half]
	fmul dword [ebp+8]
	fadd dword [half]
	fstp dword [esi]
	add esi,4
	loop noiseloop
	pop ecx
	pop esi
	pop ebp
	ret 4
endp

proc perlinnoise ;expects pointer to noisearray in esi, x and y floating point values in FPU, i.e F = x, y
	push esi
	push ebx
	push eax

	fld st0 	;x, x, y
	frndint 	;intx, x, y
	fist dword [x1]
	fchs
	faddp st1,st0	;x-intx, y
	fld st1
	frndint 	;inty, x-intx, y
	fist dword [y1]
	fchs
	faddp st2,st0	;x-intx, y-inty

	mov eax, [x1]
	add eax, noisewidth
	mov ebx, eax
	and eax, noisewidth-1
	shl eax, nwlog+2
	mov [x1],eax
	dec ebx
	and ebx, noisewidth-1
	shl ebx, nwlog+2
	mov [x2],ebx
	mov eax, [y1]
	add eax, noiseheight
	mov ebx, eax
	and eax, noiseheight-1
	shl eax, 2
	mov [y1],eax
	dec ebx
	and ebx, noiseheight-1
	shl ebx, 2
	mov [y2],ebx
			;x, y
	fld st0 	;x, x, y
	fmul st0,st2	;xy, x ,y
	fld st0 		;xy, xy, x, y
	mov ebx, [x1]
	add ebx, [y1]
	fmul dword [esi+ebx]  ;n, xy, x, y

	fld st1 	;xy, n, xy, x, y
	fchs
	fadd st0,st3	;x-xy, n, xy, x, y
	mov ebx, [x1]
	add ebx, [y2]
	fmul dword [esi+ebx]
	faddp		;n, xy, x, y

	fld st1 	;xy, n, xy, x, y
	fchs
	fadd st0,st4	;y-xy, n, xy, x, y
	mov ebx, [x2]
	add ebx, [y1]
	fmul dword [esi+ebx]
	faddp		;n, xy, x, y

	fxch st1		;xy, n, x, y
	fsub st0, st2
	fsub st0,st3
	fld1
	faddp
	mov ebx, [x2]
	add ebx, [y2]
	fmul dword [esi+ebx]
	faddp		;n, x, y
	fstp st2
	fstp st0

	pop eax
	pop ebx
	pop esi
	ret
endp

proc Turbulence ; expects x, y and size to be on the stack as double words
	push ebp
	mov ebp, esp
	push esi
	push eax

	mov esi, noisearray
	mov eax, [ebp+8]
	fldz
     turbloop:
	fild dword [ebp+12]
	mov [sizeturb],eax
	fild dword [sizeturb]
	fstp dword [sizeturb]
	fdiv dword [sizeturb]
	fild dword [ebp+16]
	fdiv dword [sizeturb]
	call perlinnoise
	fmul dword [sizeturb]
	faddp
	shr eax,1
	jnz turbloop
	fild dword [ebp+8]
	fstp dword [sizeturb]
	fdiv dword [sizeturb]
	fmul dword [half]

	pop eax
	pop esi
	pop ebp
	ret 12
endp


cproc Flat
	push ebp
	push edi
	mov ebp, esp
	mov edi, [ebp+12]
	mov ecx, 256*256
	mov al, [ebp+16]
	mov ah,[ebp+20]
	mov dl, [ebp+24]
	mov dh, 128
    flatloop:
	mov [edi], ax
	mov [edi+2],dx
	add edi,4
	loop flatloop
	pop edi
	pop ebp

	ret 16
endp

cproc Point
	push ebp
	push edi
	mov ebp, esp
	mov edi, [ebp+12]

	push dword GL_LIGHTING
	call dword [__imp__glEnable@4]

	mov eax, [ebp+48]
	mov [modambient],eax
	mov [modambient+4],eax
	mov [modambient+8],eax
	mov [modambient+12],1.0f
	push dword modambient
	push GL_LIGHT_MODEL_AMBIENT
	call dword [__imp__glLightModelfv@8]

	call dword [__imp__gluNewQuadric@0]
	push eax

	push dword 0.0f
	push dword 256.0f
	push dword 256.0f
	call dword [__imp__glTranslatef@12]

	push dword 1.0f
	push dword [ebp+40]
	push dword [ebp+36]
	call dword [__imp__glScalef@12]

	mov esi,ambient
	mov [count], 128

pointloop:
	fld dword [ebp+44]
	fld1
	fild dword [count]
	fld1
	fsubp
	fdiv dword [width]
	fsubp

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
	fxch
	fstp st0

	fld dword [ebp+16]
	fmul st0,st1
	fstp dword [esi]
	fld dword [ebp+20]
	fmul st0,st1
	fstp dword [esi+4]
	fld dword [ebp+24]
	fmul st0,st1
	fstp dword [esi+8]
	fstp st0
	mov dword [esi+12],1.0f

	push esi
	push dword GL_AMBIENT
	push dword GL_FRONT
	call dword [__imp__glMaterialfv@12]

	fild dword [count]
	fst qword [size]
	fld1
	fsubp
	fstp qword [size2]

	pop eax
	push eax

	push dword 1
	push dword 64
	push dword [size+4]
	push dword [size]
	push dword [size2+4]
	push dword [size2]
	push dword eax
	call dword [__imp__gluDisk@28]

	dec [count]
	ja pointloop
	pop eax

	;push dword [ebp+40]
	;push dword [ebp+36]
	;call dword [__imp__glPixelZoom@8]
	;push dword 0
	;push dword 384
	;call dword [__imp__glRasterPos2i@8]
	;push GL_COLOR
	;push dword 255
	;push dword 255
	;push dword 0
	;push dword 0
	;call dword [__imp__glCopyPixels@20]
	push edi
	push GL_UNSIGNED_BYTE
	push GL_RGBA
	push dword 256
	push dword 256
	push dword [ebp+32]
	push dword [ebp+28]
	call dword [__imp__glReadPixels@28]

	mov ecx, 256*256
     alphaloop:
	mov al, [ebp+52]
	mov byte [edi+3],al
	add edi,4
	loop alphaloop

	push dword GL_LIGHTING
	call dword [__imp__glDisable@4]
	call dword [__imp__glLoadIdentity@0]

	;push dword 1.0f
	;push dword 1.0f
	;call dword [__imp__glPixelZoom@8]

	pop edi
	pop ebp
	ret 36
endp

cproc Rect
	push ebp
	push edi
	mov ebp, esp
	mov edi, [ebp+12]
	push dword 128
	push dword [ebp+24]
	push dword [ebp+20]
	push dword [ebp+16]
	call dword [__imp__glColor4ub@16]
	push dword [ebp+40]
	push dword [ebp+36]
	push dword [ebp+32]
	push dword [ebp+28]
	call dword [__imp__glRecti@16]
	push edi
	push GL_UNSIGNED_BYTE
	push GL_RGBA
	push dword 256
	push dword 256
	push dword 0
	push dword 0
	call dword [__imp__glReadPixels@28]

	pop edi
	pop ebp
	ret 28
endp

cproc Plasma
	push ebp
	push edi
	mov ebp, esp
	mov edi, [ebp+12]

	fild dword [ebp+28]
	fild dword [ebp+16]
	fsubp
	fstp dword [rdiff]
	fild dword [ebp+32]
	fild dword [ebp+20]
	fsubp
	fstp dword [gdiff]
	fild dword [ebp+36]
	fild dword [ebp+24]
	fsubp
	fstp dword [bdiff]

	fldpi
	fld dword [width]
	fdivp		     ;F = Pi/128
	fldz
	fstp dword [var4]	   ;var4 = 0
	xor eax,eax
	mov ax,256		;eax = 256 (column counter)
	mov dword [row],eax
	fild dword [row]		 ; row =255
	fmul st0,st1
       pyloop:	       ; F = row, Pi/128
		mov ecx, 256
		fld st0
		fadd dword [ebp+40]    ;load offset
		fsin
		fld dword [var4]
		fsin
       pxloop:		 ;F = var2, var1, row, Pi/128
	fld st1
	fadd st0,st1
	fsin
	fld st3
	fadd st0,st2
	fsin
	faddp
	fld st2
	fadd st0,st5
	fstp st3
	fld st1
	fadd st0,st5
	fstp st2
	    ;do something with colour in st0
	    fld1 ;F = value between 0 and 1
	    fld1
	    faddp
	    faddp
	    fdiv dword [four]
	    fld dword [rdiff]
	    fmul st0,st1
	    fild dword [ebp+16]
	    faddp
	    fistp dword [red]
	    fld dword [gdiff]
	    fmul st0,st1
	    fild dword [ebp+20]
	    faddp
	    fistp dword [green]
	    fld dword [bdiff]
	    fmul st0,st1
	    fild dword [ebp+24]
	    faddp
	    fistp dword [blue]
	    mov bl, byte [red]
	    mov bh, byte [green]
	    mov dl, byte [blue]
	    mov dh, [ebp+44]
	    mov [edi], bx
	    mov [edi+2],dx
	    add edi,4
	    fstp st0
	dec cx
	jnz pxloop
	fstp st0
	fstp st0
	fsub st0,st1
	fld dword [var4]
	fadd st0,st2
	fstp dword [var4]
	dec ax
	jnz pyloop
	fstp st0
	fstp st0

	pop edi
	pop ebp
	ret 28
endp

cproc Clouds
	push ebp
	push edi
	mov ebp, esp
	push esi
	push edx
	push ecx
	push ebx
	push eax

	fild dword [ebp+28]
	fild dword [ebp+16]
	fsubp
	fstp dword [rdiff]
	fild dword [ebp+32]
	fild dword [ebp+20]
	fsubp
	fstp dword [gdiff]
	fild dword [ebp+36]
	fild dword [ebp+24]
	fsubp
	fstp dword [bdiff]

	mov eax,2036471857
	mov ebx,[ebp+48]
	imul eax,ebx
	mov [randseed],eax

	mov edi,[ebp+12]

	fstcw word [cword]
	mov ax, word [cword]
	or ax, 0c00h
	push eax
	fldcw word [esp]

	mov esi, noisearray
	push dword [ebp+40]
	call fillnoise
	mov edx,1
	;mov eax,[ebp+44] removed
	mov al,1 ;added
     shiftloop:
	shl edx,1
	dec al
	jnz shiftloop

	mov eax, 255
    cloudyloop:
	mov ecx, 255
    cloudxloop:
	push dword eax
	push dword ecx
	push dword edx
	call Turbulence

	    push edx
	    push ebx
	    fld dword [rdiff]
	    fmul st0,st1
	    fild dword [ebp+16]
	    faddp
	    fistp dword [red]
	    fld dword [gdiff]
	    fmul st0,st1
	    fild dword [ebp+20]
	    faddp
	    fistp dword [green]
	    fld dword [bdiff]
	    fmul st0,st1
	    fild dword [ebp+24]
	    faddp
	    fistp dword [blue]
	    mov bl, byte [red]
	    mov bh, byte [green]
	    mov dl, byte [blue]
	    mov dh, [ebp+52]
	    mov [edi], bx
	    mov [edi+2],dx
	    fstp st0
	    pop ebx
	    pop edx

	add edi, 4
	dec ecx
	cmp ecx,-1
	jnz cloudxloop
	dec eax
	cmp eax,-1
	jnz cloudyloop

	mov edi,[ebp+12]

	cmp dword [init],0
	jne skipinit

	push dword GL_FLAT
	call dword [__imp__glShadeModel@4]

	push dword 1
	push dword GL_UNPACK_ALIGNMENT
	call dword [__imp__glPixelStorei@8]

	push dword texname
	push dword 1
	call dword [__imp__glGenTextures@8]

	push dword [texname]
	push dword GL_TEXTURE_2D
	call dword [__imp__glBindTexture@8]

	push dword GL_REPEAT
	push dword GL_TEXTURE_WRAP_S
	push dword GL_TEXTURE_2D
	call dword [__imp__glTexParameteri@12]
	push dword GL_REPEAT
	push dword GL_TEXTURE_WRAP_T
	push dword GL_TEXTURE_2D
	call dword [__imp__glTexParameteri@12]
	push dword GL_LINEAR
	push dword GL_TEXTURE_MAG_FILTER
	push dword GL_TEXTURE_2D
	call dword [__imp__glTexParameteri@12]
	push dword GL_LINEAR
	push dword GL_TEXTURE_MIN_FILTER
	push dword GL_TEXTURE_2D
	call dword [__imp__glTexParameteri@12]

	mov dword [init],1
skipinit:
	push edi
	push dword GL_UNSIGNED_BYTE
	push dword GL_RGBA
	push dword 0
	push dword 256
	push dword 256
	push dword GL_RGBA
	push dword 0
	push GL_TEXTURE_2D
	call dword [__imp__glTexImage2D@36]

	push dword GL_TEXTURE_2D
	call dword [__imp__glEnable@4]

	push dword GL_REPLACE
	push dword GL_TEXTURE_ENV_MODE
	push dword GL_TEXTURE_ENV
	call dword [__imp__glTexEnvf@12]

	push dword [texname]
	push dword GL_TEXTURE_2D
	call dword [__imp__glBindTexture@8]

	push dword 1.0f
	push dword 1.0f
	push dword 1.0f
	call dword [__imp__glColor3f@12]

	fld1
	fstp dword [levelmul]
	mov eax, [ebp+44]

    leveltex:

	push eax

	push dword GL_QUADS
	call dword [__imp__glBegin@4]

	push dword 0
	push dword 0
	call dword [__imp__glTexCoord2f@8]
	push dword 0
	push dword 0
	call dword [__imp__glVertex2i@8]

	push dword [levelmul]
	push dword 0
	call dword [__imp__glTexCoord2f@8]
	push dword 256
	push dword 0
	call dword [__imp__glVertex2i@8]

	push dword [levelmul]
	push dword [levelmul]
	call dword [__imp__glTexCoord2f@8]
	push dword 256
	push dword 256
	call dword [__imp__glVertex2i@8]

	push dword 0
	push dword [levelmul]
	call dword [__imp__glTexCoord2f@8]
	push dword 0
	push dword 256
	call dword [__imp__glVertex2i@8]

	call dword [__imp__glEnd@0]

	push dword GL_BLEND
	call dword [__imp__glEnable@4]

	push dword GL_ONE_MINUS_SRC_ALPHA
	push dword GL_SRC_ALPHA
	call dword [__imp__glBlendFunc@8]

	pop eax
	fld dword [levelmul]
	fmul dword [half]
	fstp dword [levelmul]
	dec eax
	jnz leveltex

	push edi
	push GL_UNSIGNED_BYTE
	push GL_RGBA
	push dword 256
	push dword 256
	push dword 0
	push dword 0
	call dword [__imp__glReadPixels@28]

	push dword GL_BLEND
	call dword [__imp__glDisable@4]

	push dword GL_TEXTURE_2D
	call dword [__imp__glDisable@4]

	pop eax
	fldcw word [cword]
	pop eax
	pop ebx
	pop ecx
	pop edx
	pop esi
	pop edi
	pop ebp
	ret 44
endp

cproc AddTextures
	push ebp
	push edi
	mov ebp, esp

	push dword 0
	push dword 0
	call dword [__imp__glRasterPos2i@8]
	mov edi, [ebp+16]
	push edi
	push GL_UNSIGNED_BYTE
	push GL_RGBA
	push dword 256
	push dword 256
	call dword [__imp__glDrawPixels@20]

	push dword GL_BLEND
	call dword [__imp__glEnable@4]

	push dword GL_ONE_MINUS_SRC_COLOR
	push dword GL_SRC_COLOR
	call dword [__imp__glBlendFunc@8]

	push dword 0
	push dword 0
	call dword [__imp__glRasterPos2i@8]
	mov edi, [ebp+12]
	push edi
	push GL_UNSIGNED_BYTE
	push GL_RGBA
	push dword 256
	push dword 256
	call dword [__imp__glDrawPixels@20]

	mov edi, [ebp+20]
	push edi
	push GL_UNSIGNED_BYTE
	push GL_RGBA
	push dword 256
	push dword 256
	push dword 0
	push dword 0
	call dword [__imp__glReadPixels@28]

	push dword GL_BLEND
	call dword [__imp__glDisable@4]

	pop edi
	pop ebp
	ret 16
endp

cproc Copy
	push ebp
	push edi
	mov ebp, esp
	push esi
	push ecx
	mov edi, [ebp+16]
	mov esi, [ebp+12]
	mov ecx, 64*256*4
	rep movsd
	pop ecx
	pop esi
	pop edi
	pop ebp
	ret 12
endp


width dd 128.0f
four dd 4.0f
half dd 0.5f
randscale dd 1.5258789E-5
randseed dd 2036471857
init dd 0


modambient rd 4
ambient rd 4
noisearray rd noisewidth*noiseheight
alphatexture rd 256*256*4
texname GLuint ?
x1 dd ?
y1 dd ?
x2 dd ?
y2 dd ?
levelmul dd ?
color dd ?
cword dw ?
randomval dd ?
sizeturb dd ?
size dq ?
size2 dq ?
count dd ?
rdiff dd ?
gdiff dd ?
bdiff dd ?
var4 dd ?
row dd ?
red dd ?
green dd ?
blue dd ?


