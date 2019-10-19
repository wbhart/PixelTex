#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <gl\gl.h>
#include <gl\glu.h>
#include <gl\glaux.h>
#include "mmsystem.h"

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib,"winmm.lib")
#pragma comment(lib, "opengl32.lib")
#pragma comment(lib, "glaux.lib")
#pragma comment(lib, "glu32.lib")

#define gridwidth 20
#define linewidth 20
#define numlines 50 
#define winwidth 1024
#define winheight 768
#define noitems 3
#define menuwidth 100
#define itemwidth 20
#define numwidgets 20
#define colwidth 300
#define leftmargin 10
#define topmargin 10
#define widgetskip 15
#define widgeth 12
#define widgetw 256

int width = winwidth;
int height = winheight;

char * flatheadings[3] = {"R\0","G\0","B\0"};  //Add list of headings for each button kind ###
char * pointheadings[9] = {"R\0","G\0","B\0","Centre X\0","Centre Y\0","Radius X\0","Radius Y\0","Attenuation\0","Brightness\0"};

typedef struct colour
{
	float R, G, B;
} colour;

typedef struct Rect
{
	BOOL on;
	int x1, y1, x2, y2;
	BOOL exists;
} Rect;

typedef struct widget
{
	int kind;
	void * data;
} widget;

typedef struct button
{
	int x0, y0, x1, y1;
	char * heading;
	struct button *left, *right, *up1, *up2, *up3, *down;
	int sort;
	void * data;
	widget widgets[numwidgets];
	void * bitmap;
} button;

typedef struct pane
{
	int x0, y0, x1, y1;
	int xoff, yoff;
} pane;

typedef struct buttonState
{	
	BOOL state;
	button * button;
} buttonState;

typedef struct coords
{
	int x, y;
} coords;

typedef struct menu
{
	BOOL active;
	BOOL highlighted;
	int lit;
	int xpos, ypos, origx, origy;
	int numitems;
	char * items[20];
} menu;

typedef struct slidedata  // Add data structure for each kind of widget ###
{
	int value;
	char * heading;
} slidedata;

typedef struct flatdata  // Add data structure for each kind of button ###
{ 
	unsigned short int R, G, B;
} flatdata;

typedef struct pointdata
{
	unsigned short int R, G, B;
	unsigned short int xpos, ypos;
	unsigned short int xrad, yrad;
	float att, bright;
} pointdata;

menu menu1 = {FALSE, FALSE, 0, 0, 0, 0, 0 ,noitems, {"Flat\0","Point\0","Plasma\0",}};  // Add heading for each NEW button kind, update noitems above ###

typedef unsigned short int texture;

int oldx;   //When resizing a button, this stores the old right hand x coord of the button
int onwid = -1; //stores position of widget clicked on, else -1

button * selected = NULL;

coords down; //Stores (adjusted) mouse coordinates of when the mouse button was pressed
button oldButton; // Stores old coordinates of a button when it is moved

colour clear = {0.55f,0.5f,0.0f};
colour bcol = {0.3f, 0.3f, 0.3f};
colour slidecol = {0.5f,0.5f,0.8f}; //Add colours for each new kind of widget ###

pane leftPane = {1, 20, 350, 296, 0, 0}; 
pane rightPane = {351, 20, winwidth, 296, 0, 0};
pane bottomPane =  {1, 297, winwidth, winheight, 1, 297};

GLdouble clipzero[4] = {(GLdouble) 0.0, (GLdouble) -1.0, (GLdouble) 0.0, (GLdouble) (768.0-297.0)};

button * lines[numlines];

buttonState resizing = {FALSE,NULL};
buttonState buttonMove = {FALSE,NULL};

HDC hDC = NULL;                 // Private GDI Device Context
HGLRC hRC = NULL;               // Permanent Rendering Context
HWND hwnd = NULL;               // Holds Our Window Handle
HINSTANCE hInstance;            // Holds The Instance Of The Application

BOOL mouseLDown = FALSE;  // Is the mouse button being held down.
BOOL writing =FALSE;

BOOL g_fKeys[256];              // Array Used For The Keyboard Routine
BOOL g_fActive = TRUE;          // Window Active Flag Set To TRUE By Default
BOOL g_fFullScreen = TRUE;      // Fullscreen Flag Set To Fullscreen Mode By Default
BOOL fDone = FALSE;         // Is it time to Quit?

GLuint base;			// Base for font display list
GLYPHMETRICSFLOAT gmf[256];   

FILE * file1;

GLUquadricObj * temp;

extern void Flat(texture *, unsigned short int, unsigned short int, unsigned short int);  //Add for each new kind of button ###
extern void Point(texture *,float,float,float,unsigned short int,unsigned short int,float,float);

LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);   // Declaration For WndProc

GLvoid BuildFont(GLvoid)								// Build Our Bitmap Font
{
	HFONT	font;										// Windows Font ID
	HFONT	oldfont;									// Used For Good House Keeping

	base = glGenLists(96);								// Storage For 96 Characters

	font = CreateFont(	-12,							// Height Of Font
						0,								// Width Of Font
						0,								// Angle Of Escapement
						0,								// Orientation Angle
						FW_BOLD,						// Font Weight
						FALSE,							// Italic
						FALSE,							// Underline
						FALSE,							// Strikeout
						ANSI_CHARSET,					// Character Set Identifier
						OUT_TT_PRECIS,					// Output Precision
						CLIP_DEFAULT_PRECIS,			// Clipping Precision
						ANTIALIASED_QUALITY,			// Output Quality
						FF_DONTCARE|DEFAULT_PITCH,		// Family And Pitch
						"Arial");					// Font Name

	oldfont = (HFONT)SelectObject(hDC, font);           // Selects The Font We Want
	wglUseFontBitmaps(hDC, 32, 96, base);				// Builds 96 Characters Starting At Character 32
	SelectObject(hDC, oldfont);							// Selects The Font We Want
	DeleteObject(font);									// Delete The Font
}

GLvoid KillFont(GLvoid)									// Delete The Font List
{
	glDeleteLists(base, 96);							// Delete All 96 Characters
}

GLvoid glPrint(char *fmt)					// Custom GL "Print" Routine
{										// Pointer To List Of Arguments

	if (fmt == NULL)									// If There's No Text
		return;											// Do Nothing											// Results Are Stored In Text

	glPushAttrib(GL_LIST_BIT);							// Pushes The Display List Bits
	glListBase(base - 32);								// Sets The Base Character to 32
	glCallLists(strlen(fmt), GL_UNSIGNED_BYTE, fmt);	// Draws The Display List Text
	glPopAttrib();
	return;										// Pops The Display List Bits
}

/****************************************************************************
*                                                                                                     
* Function: InitGL
*
* Reason: Initialize Clear Colour/Projection Mode / Build Font
*
******************************************************************************/

int InitGL(GLvoid)										// All Setup For OpenGL Goes Here
{
	glShadeModel(GL_FLAT);							// Enable Smooth Shading
	glDisable(GL_DEPTH_TEST);							// Enables Depth Testing
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluOrtho2D(0,winwidth,0,winheight);
	BuildFont();
	glClipPlane(GL_CLIP_PLANE0,clipzero);
	return TRUE;										// Initialization Went OK
}

/****************************************************************************
 *                                                                          *
 * Function: ReSizeGLScene                                                  *
 *                                                                          *
 * Purpose : Resize And Initialize The GL Window.                           *
 *                                                                          *
 * History : Date      Reason                                               *
 *           02-08-26  Created                                              *
 *                                                                          *
 ****************************************************************************/

static GLvoid ReSizeGLScene(GLsizei portwidth, GLsizei portheight)
{
    // Prevent A Divide By Zero
    if (portheight == 0) portheight = 1;

    glViewport(0, 0, portwidth, portheight);
    
    width = portwidth;
    height = portheight;

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluOrtho2D(0,width,0,height);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
}

/****************************************************************************
*                                                                                                     
* Function: DrawPane
*
* Reason: Draws 3D looking pane
*
******************************************************************************/

void DrawPane(pane * DrawP)
{	
	glColor3f(clear.R+0.1f,clear.G+0.1f,clear.B+0.1f);
	glBegin(GL_LINES);
		glVertex2i(DrawP->x0,height-DrawP->y0);
		glVertex2i(DrawP->x1,height-DrawP->y0);
		glVertex2i(DrawP->x0,height-DrawP->y0);
		glVertex2i(DrawP->x0,height-DrawP->y1);
	glEnd();
	glColor3f(clear.R-0.1f,clear.G-0.1f,clear.B-0.1f);
	glBegin(GL_LINES);
		glVertex2i(DrawP->x1,height-DrawP->y1);
		glVertex2i(DrawP->x1,height-DrawP->y0);
		glVertex2i(DrawP->x1,height-DrawP->y1);
		glVertex2i(DrawP->x0,height-DrawP->y1);
	glEnd();
		
	return;
}

/****************************************************************************
*                                                                                                     
* Function: DrawButton
*
* Reason: Draws 3D Button
*
******************************************************************************/

void DrawButton(button *butt)
{
	glColor3f(bcol.R,bcol.G,bcol.B);
	glRecti(butt->x0+bottomPane.xoff,height-butt->y0-bottomPane.yoff,butt->x1+bottomPane.xoff,height-butt->y1-bottomPane.yoff);
	if (butt != selected) 
	{
		glColor3f(bcol.R+0.1f,bcol.G+0.1f,bcol.B+0.1f);
	} else glColor3f(bcol.R-0.1f,bcol.G-0.1f,bcol.B-0.1f);
	glBegin(GL_LINES);
		glVertex2i(butt->x0+1+bottomPane.xoff,height-butt->y0-1-bottomPane.yoff);
		glVertex2i(butt->x1+bottomPane.xoff,height-butt->y0-1-bottomPane.yoff);
		glVertex2i(butt->x0+1+bottomPane.xoff,height-butt->y0-1-bottomPane.yoff);
		glVertex2i(butt->x0+1+bottomPane.xoff,height-butt->y1-bottomPane.yoff);
	glEnd();
	if (butt != selected) 
	{
		glColor3f(bcol.R-0.1f,bcol.G-0.1f,bcol.B-0.1f);
	} else glColor3f(bcol.R+0.1f,bcol.G+0.1f,bcol.B+0.1f);
	glBegin(GL_LINES);
		glVertex2i(butt->x1+bottomPane.xoff,height-butt->y1-bottomPane.yoff);
		glVertex2i(butt->x1+bottomPane.xoff,height-butt->y0-1-bottomPane.yoff);
		glVertex2i(butt->x1+bottomPane.xoff,height-butt->y1-bottomPane.yoff);
		glVertex2i(butt->x0+1+bottomPane.xoff,height-butt->y1-bottomPane.yoff);
	glEnd();
	glColor3f(0.0f, 0.0f, 0.0f);
	if (butt->y0+6+bottomPane.yoff > bottomPane.y0)
	{
		glRasterPos2i(butt->x0/2+butt->x1/2-strlen(butt->heading)*3+bottomPane.xoff, height-(butt->y0+15+bottomPane.yoff));
		glPrint(butt->heading);
	}
	return;
}

/****************************************************************************
*                                                                                                     
* Function: LineNo
*
* Reason: Computes the line number the cursor is at
*
******************************************************************************/

int LineNo(int ypos)
{
	return floor(ypos/20.0f);
}

/****************************************************************************
*                                                                                                     
* Function: Pane
*
* Reason: Returns the pane the specified position is in, else returns 0
*
******************************************************************************/

int Pane(int xpos, int ypos)
{
	if ((xpos > leftPane.x0) && (xpos < leftPane.x1) && (ypos > leftPane.y0) && (ypos < leftPane.y1)) return 1;
	if ((xpos > rightPane.x0) && (xpos < rightPane.x1) && (ypos > rightPane.y0) && (ypos < rightPane.y1)) return 2;
	if ((xpos > bottomPane.x0) && (xpos < bottomPane.x1) && (ypos > bottomPane.y0) && (ypos < bottomPane.y1)) return 3;
	return 0;	
}


/****************************************************************************
*                                                                                                     
* Function: DeleteButton
*
* Reason: Deletes a Button
*
******************************************************************************/

static void DeleteButton(button * butt)
{
	if (selected = butt) selected = NULL;
	if (butt->left != NULL)
        	{
        		butt->left->right = butt->right;
        	} else 
        	{
        		lines[LineNo(butt->y0)] = butt->right;
        	}
        	if (butt->right != NULL)
        	{	
        		butt->right->left = butt->left;
        	}
        	free(butt->bitmap);
        	free(butt);
}

/****************************************************************************
*                                                                                                     
* Function: AddButton
*
* Reason: Adds Button
*
******************************************************************************/

button * AddButton(int xpos, int ypos)
{
	button *tempButton;
	int gridx, gridy,line;
	button *current;
	BOOL inserted = FALSE;
	
	line = LineNo(ypos);
	gridx = 20*round(xpos/20.0f)-2*gridwidth;
	gridy = 20*line;
	
	tempButton = calloc(1,sizeof(button));
	tempButton->x0 = gridx;
	tempButton->y0 = gridy;
	tempButton->x1 = gridx+4*gridwidth;
	tempButton->y1 = gridy+linewidth;
	tempButton->bitmap = calloc(1,256*256*3);
	
             if ((gridx+bottomPane.xoff >0) && (gridy+bottomPane.yoff > bottomPane.y0) && (gridx+4*gridwidth+bottomPane.xoff < width) && (gridy+linewidth+bottomPane.yoff < height))
             {
             	if (lines[line] == NULL) 
             {
             		lines[line] = tempButton;
		tempButton->left = NULL;
		tempButton->right = NULL;
		inserted = TRUE;
	} else
	{
		current = lines[line];
		while ((current != NULL) && (current->right != NULL))
		{
			if ((current->x1 <= tempButton->x0) && (current->right->x0 >= tempButton->x1))
			{
				tempButton->right = current->right;
				current->right = tempButton;
				tempButton->left = current;
				tempButton->right->left = tempButton;
				current = NULL;
				inserted = TRUE;
			}
			if (current !=NULL) current = current->right;
		}
		if ((!inserted) && (lines[line]->x0 >= tempButton->x1) && (tempButton->x0 > 0))
		{
			tempButton->right = lines[line];
			tempButton->right->left = tempButton;
			lines[line] = tempButton;
			tempButton->left=NULL;
			inserted = TRUE;
		} else if ((!inserted) && (current->x1 <= tempButton->x0))
		{
			tempButton->left = current;
			current ->right = tempButton;
			tempButton->right = NULL;
			inserted = TRUE;
			
		}
	}
	}
	if (!inserted) 
	{
		free(tempButton->bitmap);
		free(tempButton);
		return NULL;
	} else return tempButton;
}

/****************************************************************************
*                                                                                                     
* Function: CopyButton
*
* Reason: Copies a buttons characterisitics (incl. size) except its position and neighbours, to another 
*
******************************************************************************/

void CopyButton(button * newbutton, button * oldbutton)
{
	newbutton->bitmap = oldbutton->bitmap;
	newbutton->sort = oldbutton->sort;
	newbutton->heading = oldbutton->heading;
	newbutton->x1 = newbutton->x0 + oldbutton->x1 - oldbutton->x0;
	newbutton->y1 = newbutton->y0 + oldbutton->y1 - oldbutton->y0;
	newbutton->data = oldbutton->data;
	for (int i = 0; i<numwidgets;i++) 
	{
		newbutton->widgets[i].kind = oldbutton->widgets[i].kind;
		newbutton->widgets[i].data = oldbutton->widgets[i].data;
	}
	if (oldbutton == selected) selected = newbutton;
	return;
}
	
/****************************************************************************
*                                                                                                     
* Function: OnBoundary
*
* Reason: Determines whether given coordinates lie on the boundary of any button
*
******************************************************************************/

button * OnBoundary(int xpos, int ypos)
{
	button * current;
	
             current = lines[LineNo(ypos)];
             while (current != NULL) 
             {
             		if (((xpos > current->x0-2) && (xpos < current->x0+2)) || ((xpos > current->x1-3) && (xpos < current->x1+1))) return current;
             		current = current->right;
             	}
	return NULL;
}

/****************************************************************************
*                                                                                                     
* Function: OnButton
*
* Reason: Determines whether given coordinates lie on any button
*
******************************************************************************/

button * OnButton(int xpos, int ypos)
{
	button * current;
	
             current = lines[LineNo(ypos)];
             while (current != NULL) 
             {
             		if ((xpos >= current->x0+2) && (xpos <= current->x1-3)) return current;
             		current = current->right;
             	}
	return NULL;
}

/****************************************************************************
*                                                                                                     
* Function: Highlight
*
* Reason: Highlights any menu item hovered over
*
******************************************************************************/

void Highlight(menu * menuinf, int xpos, int ypos)
{
	if ((xpos >= menuinf->xpos) && (xpos <= menuinf->xpos+menuwidth) && (ypos >= menuinf->ypos) && (ypos < menuinf->ypos+menuinf->numitems*itemwidth))
	{
		menuinf->highlighted = TRUE;
		menuinf->lit = (ypos-menuinf->ypos)/itemwidth;
	} else menuinf->highlighted = FALSE;
	return;
}

/****************************************************************************
*                                                                                                     
* Function: DrawSlide
*
* Reason: Displays a slide widget
*
******************************************************************************/

void DrawSlide(int position, int value, char * heading)
{
	int x0, y0;
	
	y0 = rightPane.y0+topmargin;
	if (position <= numwidgets/2) 
	{
		x0 = rightPane.x0+leftmargin;
	} else
	{
		x0 = rightPane.x0+leftmargin+colwidth;
	}
	glColor3f(0.5f-0.1f, 0.5f-0.1f, 0.5f-0.1f);
	glBegin(GL_LINES);
		glVertex2i(x0,height-(y0+position*widgetskip));
		glVertex2i(x0+widgetw,height-(y0+position*widgetskip));
		glVertex2i(x0,height-(y0+position*widgetskip));
		glVertex2i(x0,height-(y0+position*widgetskip+widgeth));
	glEnd();
	glColor3f(0.5f+0.1f, 0.5f+0.1f, 0.5f+0.1f);
	glBegin(GL_LINES);
		glVertex2i(x0+widgetw,height-(y0+position*widgetskip+widgeth));
		glVertex2i(x0+widgetw,height-(y0+position*widgetskip));
		glVertex2i(x0+widgetw,height-(y0+position*widgetskip+widgeth));
		glVertex2i(x0,height-(y0+position*widgetskip+widgeth));
	glEnd();
	glColor3f(0.5f, 0.5f, 0.5f);
	glRecti(x0,height-(y0+position*widgetskip),x0+widgetw,height-(y0+position*widgetskip+widgeth));
	glColor3f(slidecol.R, slidecol.G, slidecol.B);
	glRecti(x0,height-(y0+position*widgetskip),x0+value,height-(y0+position*widgetskip+widgeth-1));
	glColor3f(0.0f, 0.0f, 0.0f);
	glRasterPos2i(x0+widgetw+5,height-(y0+position*widgetskip+widgeth-1));
	glPrint(heading);
		
	return;
}

/****************************************************************************
*                                                                                                     
* Function: Menu
*
* Reason: Displays a menu at the position given
*
******************************************************************************/

void Menu(menu * menuinf)
{
	glColor3f(0.5f, 0.5f, 1.0f);
	glRecti(menuinf->xpos, height-menuinf->ypos, menuinf->xpos+menuwidth, height - (menuinf->ypos+menuinf->numitems*itemwidth));
	if (menuinf->highlighted)
	{
		glColor3f(0.5f,0.2f,0.5f);
		glRecti(menuinf->xpos, height-(menuinf->ypos+menuinf->lit*itemwidth), menuinf->xpos+menuwidth, height-(menuinf->ypos+(menuinf->lit+1)*itemwidth));
	}
	glColor3f(0.0f, 0.0f, 0.0f);
	for (int i = 0; i<menuinf->numitems;i++)
	{
		glRasterPos2i(menuinf->xpos+20, height-(menuinf->ypos+15+i*itemwidth));
		glPrint(menuinf->items[i]);
	}
	return;
}

/****************************************************************************
*                                                                                                     
* Function: OnWidget
*
* Reason: Returns position of a slide if clicked on, else -1
*
******************************************************************************/

int OnWidget(int xpos, int ypos)
{
	for (int i=0; i<numwidgets/2; i++)
	{
		if ((xpos >= rightPane.x0 + leftmargin) && (xpos < rightPane.x0 + leftmargin + widgetw) && (ypos > rightPane.y0 + topmargin + i*widgetskip) && (ypos < rightPane.y0 + topmargin + i*widgetskip + widgeth))
		{
			return i;
		}
		if ((xpos >= rightPane.x0 + leftmargin + colwidth) && (xpos <= rightPane.x0 + leftmargin + widgetw +colwidth) && (ypos > rightPane.y0 + topmargin + i*widgetskip) && (ypos < rightPane.y0 + topmargin + i*widgetskip + widgeth))
		{
			return (int) (numwidgets/2) + i;
		}	
	}
	return -1;
}

/****************************************************************************
*                                                                                                     
* Function: LButtonDown2
*
* Reason: Updates widget value if a widget is clicked on
*
******************************************************************************/

static void LButtonDown2(int xpos, int ypos)
{
	if ((selected !=NULL) && (selected->widgets[onwid].data != NULL) && (onwid != -1))
	{
		switch (selected->widgets[onwid].kind) //Add case for each new kind of widget ###
		{
			case 1: //widget is a slide widget
			{
				((slidedata *) selected->widgets[onwid].data)->value = xpos - rightPane.x0 - leftmargin;
			} break;
		}
		switch (selected->sort)  //Add case for each new button sort ###
		{
			case 0:  
			{
				switch (onwid)  //Case for each flat button widget position
				{
					case 0: ((flatdata *) selected->data)->R = xpos - rightPane.x0 - leftmargin; break;
					case 1: ((flatdata *) selected->data)->G = xpos - rightPane.x0 - leftmargin; break;
					case 2: ((flatdata *) selected->data)->B = xpos - rightPane.x0 - leftmargin; break;
				}
			} break;
			case 1:
			{
				switch (onwid)  //Case for each point button widget position
				{
					case 0: ((pointdata *) selected->data)->R = xpos - rightPane.x0 - leftmargin; break;
					case 1: ((pointdata *) selected->data)->G = xpos - rightPane.x0 - leftmargin; break;
					case 2: ((pointdata *) selected->data)->B = xpos - rightPane.x0 - leftmargin; break;
					case 3: ((pointdata *) selected->data)->xpos = xpos - rightPane.x0 - leftmargin; break;
					case 4: ((pointdata *) selected->data)->ypos = xpos - rightPane.x0 - leftmargin; break;
					case 5: ((pointdata *) selected->data)->xrad = xpos - rightPane.x0 - leftmargin + 1; break;
					case 6: ((pointdata *) selected->data)->yrad = xpos - rightPane.x0 - leftmargin + 1; break;
					case 7: ((pointdata *) selected->data)->att = (xpos - rightPane.x0 - leftmargin + 1)/256.0f; break;
					case 8: ((pointdata *) selected->data)->bright = (xpos - rightPane.x0 - leftmargin + 1)/256.0f; break;
				}
			} break;
		}
	}	 	
}
	

/****************************************************************************
*                                                                                                     
* Function: LButtonDown3
*
* Reason: Displays a menu at the position given
*
******************************************************************************/

static void LButtonDown3(int xpos, int ypos)
{
	down.x = xpos-bottomPane.xoff;
        	down.y = ypos-bottomPane.yoff;
	if ((OnBoundary(xpos-bottomPane.xoff,ypos-bottomPane.yoff) != NULL)&& (xpos >= (OnBoundary(xpos-bottomPane.xoff,ypos-bottomPane.yoff)->x1+bottomPane.xoff)-3)) 
        	{
        		SetCursor(LoadCursor(NULL,IDC_SIZEWE));
        		resizing.state=TRUE;
        		resizing.button = OnBoundary(xpos-bottomPane.xoff,ypos-bottomPane.yoff);
        		oldx = resizing.button->x1;
        	} else if (OnButton(xpos-bottomPane.xoff,ypos-bottomPane.yoff) != NULL)
        	{
        		buttonMove.state = TRUE;
        		buttonMove.button = OnButton(xpos-bottomPane.xoff,ypos-bottomPane.yoff);
        		oldButton.x0 = buttonMove.button->x0;
        		oldButton.x1 = buttonMove.button->x1;
        		oldButton.y0 = buttonMove.button->y0;
        		oldButton.y1 = buttonMove.button->y1;
        		if (buttonMove.button->left != NULL)
        		{
        			buttonMove.button->left->right = buttonMove.button->right;
        		} else 
        		{
        			lines[LineNo(ypos-bottomPane.yoff)] = buttonMove.button->right;
        		}
        		if (buttonMove.button->right != NULL)
        		{	
        			buttonMove.button->right->left = buttonMove.button->left;
        		}
        	}
}

/****************************************************************************
*                                                                                                     
* Function: GenerateTexture
*
* Reason: Generates the texture for the currently selected button (pointed to by global variable "selected"
*
******************************************************************************/

void GenerateTexture(void)
{
	switch (selected->sort) //Case for each kind of button ###
	{
		case 0:
		{
			Flat(selected->bitmap, ((flatdata *)selected->data)->R,((flatdata *)selected->data)->G,((flatdata *)selected->data)->B);
		} break;
		case 1:
		{
			Point(selected->bitmap,((pointdata *)selected->data)->R/255.0,((pointdata *)selected->data)->G/255.0,((pointdata *)selected->data)->B/255.0,((pointdata *)selected->data)->xpos+256+((pointdata *)selected->data)->xrad,((pointdata *)selected->data)->ypos+((pointdata *)selected->data)->yrad-128,((pointdata *)selected->data)->xrad/128.0f,((pointdata *)selected->data)->yrad/128.0f);
			glDisable(GL_LIGHTING);
		} break;
	}
	return;
}

/****************************************************************************
 *                                                                          *
 * Function: DrawGLScene                                                    *
 *                                                                          *
 * Purpose : Here's Where We Do All The Drawing.                            *
 *                                                                          *
 * History : Date      Reason                                               *
 *           02-08-26  Created                                              *
 *                                                                          *
 ****************************************************************************/

static int DrawGLScene(GLvoid)
{   
    button *current;
    
    glClearColor( 0.0f,  0.0f,  0.0f, 0.0f);				    			// Black Background		
    glClear(GL_COLOR_BUFFER_BIT);
    if (selected != NULL)
    {
    	GenerateTexture(); //Generates the texture specified by the currently selected button
    	
    }

    glClearColor(clear.R, clear.G, clear.B, 0.0f);	//Background colour	
    glClear(GL_COLOR_BUFFER_BIT);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    
    glEnable(GL_CLIP_PLANE0);
    for (int i = 0; i<numlines; i++)
    {
    	current = lines[i];
    	while (current != NULL)
    	{
    		DrawButton(current);
    		current = current->right;
    	} 
    }
    
    if (resizing.state) DrawButton(resizing.button);
    if (buttonMove.state) DrawButton(buttonMove.button);
    
    glDisable(GL_CLIP_PLANE0);
    
    if (selected != NULL)
    {
    	for (int i = 0; i<numwidgets;i++)
    	{
    		switch (selected->widgets[i].kind) //New case for each kind of widget ###
    		{
    			case 1: //we have a slide widget
    			{
    				DrawSlide(i,((slidedata *)selected->widgets[i].data)->value,((slidedata *)selected->widgets[i].data)->heading);
    			} break;
    		}
    			
    	}
    	glColor3f(0.0f, 0.0f, 0.0f);
	char temp[20];
    	switch (selected->sort) //New case for each kind of button ###
    	{
    		case 0: //Flat button - display data values on widgets
    		{
    			_itoa(((flatdata *)selected->data)->R,temp,10);
    			glRasterPos2i(rightPane.x0+leftmargin+5,height-(rightPane.y0+topmargin+widgeth-1));
			glPrint(temp);
			_itoa(((flatdata *)selected->data)->G,temp,10);
    			glRasterPos2i(rightPane.x0+leftmargin+5,height-(rightPane.y0+topmargin+1*widgetskip+widgeth-1));
			glPrint(temp);
			_itoa(((flatdata *)selected->data)->B,temp,10);
    			glRasterPos2i(rightPane.x0+leftmargin+5,height-(rightPane.y0+topmargin+2*widgetskip+widgeth-1));
			glPrint(temp);
		} break;
		case 1: //Point button - display data values on widgets
    		{
    			_itoa(((pointdata *)selected->data)->R,temp,10);
    			glRasterPos2i(rightPane.x0+leftmargin+5,height-(rightPane.y0+topmargin+widgeth-1));
			glPrint(temp);
			_itoa(((pointdata *)selected->data)->G,temp,10);
    			glRasterPos2i(rightPane.x0+leftmargin+5,height-(rightPane.y0+topmargin+1*widgetskip+widgeth-1));
			glPrint(temp);
			_itoa(((pointdata *)selected->data)->B,temp,10);
    			glRasterPos2i(rightPane.x0+leftmargin+5,height-(rightPane.y0+topmargin+2*widgetskip+widgeth-1));
			glPrint(temp);
			_itoa(((pointdata *)selected->data)->xpos,temp,10);
    			glRasterPos2i(rightPane.x0+leftmargin+5,height-(rightPane.y0+topmargin+3*widgetskip+widgeth-1));
			glPrint(temp);
			_itoa(((pointdata *)selected->data)->ypos,temp,10);
    			glRasterPos2i(rightPane.x0+leftmargin+5,height-(rightPane.y0+topmargin+4*widgetskip+widgeth-1));
			glPrint(temp);
			_itoa(((pointdata *)selected->data)->xrad,temp,10);
    			glRasterPos2i(rightPane.x0+leftmargin+5,height-(rightPane.y0+topmargin+5*widgetskip+widgeth-1));
			glPrint(temp);
			_itoa(((pointdata *)selected->data)->yrad,temp,10);
    			glRasterPos2i(rightPane.x0+leftmargin+5,height-(rightPane.y0+topmargin+6*widgetskip+widgeth-1));
			glPrint(temp);
			//temp=(char *)((pointdata *)selected->data)->att;
			//glRasterPos2i(rightPane.x0+leftmargin+5,height-(rightPane.y0+topmargin+7*widgetskip+widgeth-1));
			//glPrint(temp);
			//temp=(char *)((pointdata *)selected->data)->bright;
			//glRasterPos2i(rightPane.x0+leftmargin+5,height-(rightPane.y0+topmargin+8*widgetskip+widgeth-1));
			//glPrint(temp);	
		} break;
	}
	glRasterPos2i(45,height-286);
	glDrawPixels(256,256,GL_RGB,GL_UNSIGNED_BYTE,selected->bitmap);
    }
    
    DrawPane(&bottomPane);
    DrawPane(&rightPane);
    DrawPane(&leftPane);
    
    glColor3f(0.0f,0.0f,0.0f);
    glRasterPos2i(390,height-15);
    glPrint("PixelTex 1.0  -  William Hart 2005\0");
    
    if (menu1.active) Menu(&menu1); //Display menu
	
    return TRUE;  // Keep Going
}

/****************************************************************************
 *                                                                          *
 * Function: KillGLWindow                                                   *
 *                                                                          *
 * Purpose : Properly Kill The Window.                                      *
 *                                                                          *
 * History : Date      Reason                                               *
 *           02-08-26  Created                                              *
 *                                                                          *
 ****************************************************************************/

static GLvoid KillGLWindow(GLvoid)
{
    if (g_fFullScreen)
    {
        ChangeDisplaySettings(NULL, 0);
    }

    if (hRC)
    {
        if (!wglMakeCurrent(NULL, NULL))
            MessageBox(NULL, "Release Of DC And RC Failed.", "SHUTDOWN ERROR", MB_OK|MB_ICONINFORMATION);

        if (!wglDeleteContext(hRC))
            MessageBox(NULL, "Release Rendering Context Failed.", "SHUTDOWN ERROR", MB_OK|MB_ICONINFORMATION);

        hRC = NULL;
    }

    if (hDC && !ReleaseDC(hwnd, hDC))
    {
        MessageBox(NULL, "Release Device Context Failed.", "SHUTDOWN ERROR", MB_OK|MB_ICONINFORMATION);
        hDC = NULL;
    }

    if (hwnd && !DestroyWindow(hwnd))
    {
        MessageBox(NULL, "Could Not Release hwnd.", "SHUTDOWN ERROR", MB_OK|MB_ICONINFORMATION);
        hwnd = NULL;
    }

    if (!UnregisterClass("OpenGL", hInstance))
    {
        MessageBox(NULL, "Could Not Unregister Class.", "SHUTDOWN ERROR", MB_OK|MB_ICONINFORMATION);
        hInstance = NULL;
    }
    
    KillFont();
}

/****************************************************************************
 *                                                                          *
 * Function: CreateGLWindow                                                 *
 *                                                                          *
 * Purpose : This Code Creates Our OpenGL Window.                           *
 *                                                                          *
 * History : Date      Reason                                               *
 *           02-08-26  Created                                              *
 *                                                                          *
 ****************************************************************************/

BOOL CreateGLWindow(char* title, int width, int height, int bits, BOOL fullscreenflag)
{
    static PIXELFORMATDESCRIPTOR pfd = {0};
    GLuint PixelFormat;     // Holds The Results After Searching For A Match
    WNDCLASS wc;            // Windows Class Structure
    DWORD dwExStyle;        // Window Extended Style
    DWORD dwStyle;          // Window Style
    RECT rcWindow;

    SetRect(&rcWindow, 0, 0, width, height);

    g_fFullScreen = fullscreenflag;

    hInstance = GetModuleHandle(NULL);

    wc.style = CS_HREDRAW|CS_VREDRAW|CS_OWNDC;
    wc.lpfnWndProc  = (WNDPROC)WndProc;
    wc.cbClsExtra = 0;
    wc.cbWndExtra = 0;
    wc.hInstance = hInstance;
    wc.hIcon = LoadIcon(NULL, IDI_WINLOGO);
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground = NULL;
    wc.lpszMenuName = NULL;
    wc.lpszClassName = "OpenGL";

    // Attempt To Register The Window Class.
    if (!RegisterClass(&wc))
    {
        MessageBox(NULL, "Failed To Register The Window Class.", "ERROR", MB_OK|MB_ICONEXCLAMATION);
        return FALSE;
    }

    // Attempt Fullscreen Mode?
    if (g_fFullScreen)
    {
        DEVMODE dmScreenSettings;

        memset(&dmScreenSettings, 0, sizeof(dmScreenSettings));
        dmScreenSettings.dmSize = sizeof(dmScreenSettings);
        dmScreenSettings.dmPelsWidth = width;
        dmScreenSettings.dmPelsHeight = height;
        dmScreenSettings.dmBitsPerPel = bits;
        dmScreenSettings.dmFields=DM_BITSPERPEL|DM_PELSWIDTH|DM_PELSHEIGHT;

        // Try To Set Selected Mode And Get Results.  NOTE: CDS_FULLSCREEN Gets Rid Of Start Bar.
        if (ChangeDisplaySettings(&dmScreenSettings, CDS_FULLSCREEN) != DISP_CHANGE_SUCCESSFUL)
        {
            // If The Mode Fails, Offer Two Options: Quit Or Use Windowed Mode.
            if (MessageBox(NULL, "The Requested Fullscreen Mode Is Not Supported By\nYour Video Card. Use Windowed Mode Instead?", "OpenGL sample", MB_YESNO|MB_ICONEXCLAMATION) == IDYES)
            {
                // Windowed Mode Selected. Fullscreen = FALSE
                g_fFullScreen = FALSE;
            }
            else
            {
                // Pop Up A Message Box Letting User Know The Program Is Closing.
                MessageBox(NULL, "Program Will Now Close.", "ERROR", MB_OK|MB_ICONSTOP);
                return FALSE;
            }
        }
        
    }

    // Are We Still In Fullscreen Mode?
    if (g_fFullScreen)
    {
        dwExStyle = WS_EX_APPWINDOW;
        dwStyle = WS_POPUP;
    }
    else
    {
        dwExStyle = WS_EX_APPWINDOW|WS_EX_WINDOWEDGE;
        dwStyle = WS_OVERLAPPEDWINDOW;
    }

    // Adjust Window To True Requested Size.
    AdjustWindowRectEx(&rcWindow, dwStyle, FALSE, dwExStyle);

    // Create The Window.
    if (!(hwnd = CreateWindowEx(dwExStyle, "OpenGL", title, dwStyle|WS_CLIPSIBLINGS|WS_CLIPCHILDREN,
        0, 0, rcWindow.right - rcWindow.left, rcWindow.bottom - rcWindow.top, NULL, NULL, hInstance, NULL)))
    {
        KillGLWindow();  // Reset The Display
        MessageBox(NULL, "Window Creation Error.", "ERROR", MB_OK|MB_ICONEXCLAMATION);
        return FALSE;
    }

    pfd.nSize = sizeof(PIXELFORMATDESCRIPTOR);
    pfd.nVersion = 1;
    pfd.dwFlags = PFD_DRAW_TO_WINDOW|PFD_SUPPORT_OPENGL|PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = bits;
    pfd.cDepthBits = 32;
    pfd.iLayerType = PFD_MAIN_PLANE;

    if (!(hDC = GetDC(hwnd)))  /* Did We Get A Device Context? */
    {
        KillGLWindow();  // Reset The Display
        MessageBox(NULL, "Can't Create A GL Device Context.", "ERROR", MB_OK|MB_ICONEXCLAMATION);
        return FALSE;
    }

    if (!(PixelFormat = ChoosePixelFormat(hDC, &pfd)))  /* Did Windows Find A Matching Pixel Format? */
    {
        KillGLWindow();  // Reset The Display
        MessageBox(NULL, "Can't Find A Suitable PixelFormat.", "ERROR", MB_OK|MB_ICONEXCLAMATION);
        return FALSE;
    }

    if(!SetPixelFormat(hDC,PixelFormat,&pfd))  /* Are We Able To Set The Pixel Format? */
    {
        KillGLWindow();  // Reset The Display
        MessageBox(NULL, "Can't Set The PixelFormat.", "ERROR", MB_OK|MB_ICONEXCLAMATION);
        return FALSE;
    }

    if (!(hRC = wglCreateContext(hDC)))  /* Are We Able To Get A Rendering Context? */
    {
        KillGLWindow();  // Reset The Display
        MessageBox(NULL, "Can't Create A GL Rendering Context.", "ERROR", MB_OK|MB_ICONEXCLAMATION);
        return FALSE;
    }

    if(!wglMakeCurrent(hDC,hRC))  /* Try To Activate The Rendering Context */
    {
        KillGLWindow();  // Reset The Display
        MessageBox(NULL, "Can't Activate The GL Rendering Context.", "ERROR", MB_OK|MB_ICONEXCLAMATION);
        return FALSE;
    }

    ShowWindow(hwnd, SW_SHOW);
    SetForegroundWindow(hwnd);      // Slightly Higher Priority
    SetFocus(hwnd);                 // Sets Keyboard Focus To The Window
    ReSizeGLScene(width, height);   // Set Up Our Perspective GL Screen
    
    if (!InitGL())									// Initialize Our Newly Created GL Window
    {
	KillGLWindow();								// Reset The Display
	MessageBox(NULL,"Initialization Failed.","ERROR",MB_OK|MB_ICONEXCLAMATION);
	return FALSE;								// Return FALSE
     }
	
    return TRUE;
}

/****************************************************************************
 *                                                                          *
 * Function: WndProc                                                        *
 *                                                                          *
 * Purpose : Window callback procedure.                                     *
 *                                                                          *
 * History : Date      Reason                                               *
 *           02-08-26  Created                                              *
 *                                                                          *
 ****************************************************************************/

LRESULT CALLBACK WndProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    button * temp;
    
    switch (uMsg)
    {
        case WM_ACTIVATE:  /* Watch For Window Activate Message */
        {
            g_fActive = !HIWORD(wParam);
            return 0;
        }

        case WM_SYSCOMMAND:  /* Intercept System Commands */
        {
            switch (wParam)  /* Check System Calls */
            {
                case SC_SCREENSAVE:     // Screensaver Trying To Start?
                case SC_MONITORPOWER:   // Monitor Trying To Enter Powersave?
                return 0;               // Prevent From Happening
            }
            break;
        }

        case WM_CLOSE:  /* Did We Receive A Close Message? */
        {
                PostQuitMessage(0);
                return 0;
        }
        
        case WM_KEYDOWN:
        {
            g_fKeys[wParam] = TRUE;
            if (g_fKeys[VK_BACK])
            {
       		if (selected != NULL) DeleteButton(selected);
            }
            return 0;
        }

        case WM_KEYUP:
        {
            g_fKeys[wParam] = FALSE;
            return 0;
        }
        
        case WM_CHAR:
        {
        	if (!g_fKeys[VK_ESCAPE]&&!g_fKeys['S']&&!g_fKeys['L'])
        	{
       	}
       	if (g_fKeys['S'])
       	{
       	 	if (!writing)
       	 	{ 
   			writing=TRUE;
       	 		file1 = fopen("0001.sav","wb");
       	 	 	
       	 	 	fclose(file1);
       	 	 	writing=FALSE;
       	 	 }
	}
	if (g_fKeys['L'])
       	{
       	 	if (!writing)
       	 	{ 
   			writing=TRUE;
   			if (file1 = fopen("0001.sav","rb"))
   			{
   				
   				fclose(file1);
   			}
   			writing=FALSE;
   		}
   	}	
        	return 0;
        }
        
        case WM_SIZE:  /* Resize The OpenGL Window */
        {
            ReSizeGLScene(LOWORD(lParam), HIWORD(lParam));  // LoWord=Width, HiWord=Height
            return 0;
        }
        
        case WM_MOUSEMOVE:
        {
        	if (mouseLDown)
        	{
        		if (onwid != -1) //We are dragging some kind of widget
        		{
        			int y0 = rightPane.y0+topmargin;
        			if (onwid <= numwidgets/2) 
        			{
        				y0 += onwid*widgetskip +2;
        				if ((LOWORD(lParam) < rightPane.x0+leftmargin+widgetw) && (LOWORD(lParam) >= rightPane.x0+leftmargin))
        				{
        					LButtonDown2(LOWORD(lParam),y0);
        				}
        			} else
        			{
        				y0 += onwid*(widgetskip - numwidgets/2)+2;
        				if ((LOWORD(lParam) < rightPane.x0+leftmargin+colwidth+widgetw) && (LOWORD(lParam) >= rightPane.x0+leftmargin+colwidth))
        				{
        					LButtonDown2(LOWORD(lParam),y0);
        				}
        			}
		} else if (resizing.state == TRUE) //We are resizing a button
        		{
			SetCursor(LoadCursor(NULL,IDC_SIZEWE));
			if (LOWORD(lParam)-bottomPane.xoff >= resizing.button->x0 + 4*gridwidth) resizing.button->x1 = LOWORD(lParam)-bottomPane.xoff;
		} else if (buttonMove.state) //We are moving a button
		{
			buttonMove.button->x0 = oldButton.x0 + (LOWORD(lParam) - down.x - bottomPane.xoff);
			buttonMove.button->x1 = oldButton.x1 + (LOWORD(lParam) - down.x - bottomPane.xoff);
			buttonMove.button->y0 = oldButton.y0 + (HIWORD(lParam) - down.y - bottomPane.yoff);
			buttonMove.button->y1 = oldButton.y1 + (HIWORD(lParam) - down.y - bottomPane.yoff);
		} else //We are dragging in a nondescript location
		{
			SetCursor(LoadCursor(NULL,IDC_ARROW));
			if ((HIWORD(lParam) > bottomPane.y0) && (HIWORD(lParam) - down.y <= bottomPane.y0) && (HIWORD(lParam) - down.y >= bottomPane.y1-linewidth*numlines)) 
			{
				bottomPane.yoff = HIWORD(lParam) - down.y;
			}
			if ((HIWORD(lParam) > bottomPane.y0) && (LOWORD(lParam) - down.x <= 0) && (LOWORD(lParam) - down.x >= bottomPane.x1-2000))
			{
				bottomPane.xoff = LOWORD(lParam) - down.x;
			}
		};	
	} else //Left button is not down and we are just moving around
	{
		if (menu1.active)  //Right menu is up  
		{
			Highlight(&menu1, LOWORD(lParam),HIWORD(lParam));
		} else if ((HIWORD(lParam) > bottomPane.y0) && (OnBoundary(LOWORD(lParam)-bottomPane.xoff,HIWORD(lParam)-bottomPane.yoff)!=NULL) && (LOWORD(lParam) >= (OnBoundary(LOWORD(lParam)-bottomPane.xoff,HIWORD(lParam)-bottomPane.yoff)->x1+bottomPane.xoff)-3)) 
		{
			SetCursor(LoadCursor(NULL,IDC_SIZEWE));  // We are onboundary of button so change to resize cursor
		} else
		{
			SetCursor(LoadCursor(NULL,IDC_ARROW)); // We are not on button boundary, so change to ordinary cursor 
		};
	}
	return 0;
        }
        
        case WM_RBUTTONDOWN:
        {
 	menu1.active = TRUE;
 	menu1.xpos = menu1.origx = LOWORD(lParam);
 	menu1.ypos = menu1.origy = HIWORD(lParam);
 	if (menu1.origx > winwidth/2) menu1.xpos -= menuwidth;
	if (menu1.origy > winheight/2) menu1.ypos -= menu1.numitems*itemwidth;
 	return 0;	
        }

        case WM_LBUTTONDOWN: 
        {
        	mouseLDown = TRUE;
        	if (menu1.active)
        	{
        		if (menu1.highlighted)
        		{
        			button * temp = AddButton(menu1.origx-bottomPane.xoff,menu1.origy-bottomPane.yoff);   
        			if (temp != NULL)
        			{
        				temp->sort = menu1.lit;
        				temp->heading = menu1.items[menu1.lit];  
        				switch (temp->sort)  //New case for each type of button ### - putting default data into button and widgets
        				{
        					case 0:    //we have a flat operator
        					{
        						temp->data = calloc(1,sizeof(flatdata));
        						((flatdata *) temp->data)->R = 255;
        						((flatdata *) temp->data)->G = 255;
        						((flatdata *) temp->data)->B = 255;	
        						for (int i = 0; i<3; i++)
        						{
        							temp->widgets[i].kind = 1;
        							temp->widgets[i].data = calloc(1,sizeof(slidedata));
        							((slidedata *) temp->widgets[i].data)->value = 255;
        							((slidedata *) temp->widgets[i].data)->heading = flatheadings[i];
      						} 
        					} break;
        					case 1:    //we have a point operator
        					{
        						temp->data = calloc(1,sizeof(pointdata));
        						((pointdata *) temp->data)->R = 255;
        						((pointdata *) temp->data)->G = 255;
        						((pointdata *) temp->data)->B = 255;
        						((pointdata *) temp->data)->xpos = 128;	
        						((pointdata *) temp->data)->ypos = 128;	
        						((pointdata *) temp->data)->xrad = 128;	
        						((pointdata *) temp->data)->yrad = 128;	
        						((pointdata *) temp->data)->att = 1.0f;	
        						((pointdata *) temp->data)->bright = 1.0f;		
        						for (int i = 0; i<9; i++)
        						{
        							temp->widgets[i].kind = 1;
        							temp->widgets[i].data = calloc(1,sizeof(slidedata));
        							((slidedata *) temp->widgets[i].data)->heading = pointheadings[i];
      						} 
      						for (int i = 0; i<3; i++)
        						{
        							((slidedata *) temp->widgets[i].data)->value = 255;
        						}
        						for (int i = 3; i<7; i++)
        						{
        							((slidedata *) temp->widgets[i].data)->value = 128;
        						}
        						for (int i = 7; i<9; i++)
        						{
        							((slidedata *) temp->widgets[i].data)->value = 1.0f;
        						}		
        					} break;
        				}
        			} 
        			 
        		}
        		menu1.active = FALSE;
        	} else
             {
        		switch (Pane(LOWORD(lParam),HIWORD(lParam)))
        		{
        			case 2: 
        			{
        				onwid = OnWidget(LOWORD(lParam),HIWORD(lParam));
				LButtonDown2(LOWORD(lParam),HIWORD(lParam)); 
        			} break; 
        			case 3: LButtonDown3(LOWORD(lParam),HIWORD(lParam)); break;
        		}
        	}
        	return 0;
        }
        
        case WM_LBUTTONUP:
        {
        	mouseLDown = FALSE;
        	onwid = -1;  // no widget clicked any more
        	int newx = 20*round((LOWORD(lParam)-bottomPane.xoff)/20.0f);
        	if ((resizing.state) && (newx >= resizing.button->x0+4*gridwidth) && ((resizing.button->right == NULL) || (newx <= resizing.button->right->x0))) 
        	{
        		resizing.button->x1 = newx;
        	} else if (resizing.state) resizing.button->x1 = oldx;
        	if (buttonMove.state)
        	{
        		if ((temp = AddButton(buttonMove.button->x0+2*gridwidth,buttonMove.button->y0+(int)(linewidth/2)))!=NULL)
        		{
        			CopyButton(temp,buttonMove.button);
        			if ((temp->x0 == oldButton.x0) && (temp->y0 == oldButton.y0)) selected = temp;
        			free(buttonMove.button);
        			buttonMove.state=FALSE;
        		} else
        		{
        			temp = AddButton(oldButton.x0+2*gridwidth,oldButton.y0+(int)(linewidth/2));
        			CopyButton(temp,buttonMove.button);
        			free(buttonMove.button);
        			buttonMove.state=FALSE;
        		}
        	}
        	resizing.state = FALSE;
        	buttonMove.state=FALSE;
        	return 0;
        }
        
    }

    // Pass All Unhandled Messages To DefWindowProc.
    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

/****************************************************************************
 *                                                                          *
 * Function: WinMain                                                        *
 *                                                                          *
 * Purpose : Here is were the show starts.                                  *
 *                                                                          *
 * History : Date      Reason                                               *
 *           02-08-26  Created                                              *
 *                                                                          *
 ****************************************************************************/

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    MSG msg;

    // Ask The User Which Screen Mode They Prefer.
    if (MessageBox(NULL, "Would You Like To Run In Fullscreen Mode?", "Start FullScreen?", MB_YESNO|MB_ICONQUESTION) == IDNO)
        g_fFullScreen = FALSE;  // Windowed Mode

    // Create Our OpenGL Window.
    if (!CreateGLWindow("PixelTex 1.0", winwidth,winheight,32, g_fFullScreen))
        return 0;
        
    for(int i; i< numlines; i++) lines[i]=NULL;
        
    while (!fDone)
    {
        if (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))  /* Is There A Message Waiting? */
        {
            if (msg.message == WM_QUIT)  /* Have We Received A Quit Message? */
            {
                fDone = TRUE;
            }
            else  /* If Not, Deal With Window Messages */
            {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
        }
        else  /* If There Are No Messages */
        {
            // Draw The Scene. Watch For ESC Key And Quit Messages From DrawGLScene()
            if ((g_fActive && !DrawGLScene()) || g_fKeys[VK_ESCAPE])  /* Active?  Was There A Quit Received? */
            {
                fDone = TRUE;
            }
            else  /* Not Time To Quit, Update Screen */
            {
                SwapBuffers(hDC);  // Swap Buffers (Double Buffering)
            }
        }
    }

    // Shutdown
    KillGLWindow();  // Kill The Window
    return msg.wParam;
}
                                                                                                                                                                                        