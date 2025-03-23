// menus.cpp: ingame menu system (also used for scores and serverlist)

#include "cube.h"

#import "Menu.h"

#import "Command.h"
#import "DynamicEntity.h"
#import "MenuItem.h"

static OFMutableArray<OFNumber *> *menuStack;
static OFMutableArray<Menu *> *menus;
static int vmenu = -1;

void
menuset(int menu)
{
	if ((vmenu = menu) >= 1)
		[player1 resetMovement];
	if (vmenu == 1)
		menus[1].menusel = 0;
}

COMMAND(showmenu, ARG_1STR, ^(OFString *name) {
	int i = 0;
	for (Menu *menu in menus) {
		if (i > 1 && [menu.name isEqual:name]) {
			menuset(i);
			return;
		}
		i++;
	}
})

void
sortmenu()
{
	[menus[0].items sort];
}

void refreshservers();

bool
rendermenu()
{
	if (vmenu < 0) {
		[menuStack removeAllObjects];
		return false;
	}

	if (vmenu == 1)
		refreshservers();

	Menu *m = menus[vmenu];
	OFString *title;
	if (vmenu > 1)
		title = [OFString stringWithFormat:@"[ %@ menu ]", m.name];
	else
		title = m.name;
	int mdisp = m.items.count;
	int w = 0;
	for (int i = 0; i < mdisp; i++) {
		int x = text_width(m.items[i].text);
		if (x > w)
			w = x;
	}
	int tw = text_width(title);
	if (tw > w)
		w = tw;
	int step = FONTH / 4 * 5;
	int h = (mdisp + 2) * step;
	int y = (VIRTH - h) / 2;
	int x = (VIRTW - w) / 2;
	blendbox(x - FONTH / 2 * 3, y - FONTH, x + w + FONTH / 2 * 3,
	    y + h + FONTH, true);
	draw_text(title, x, y, 2);
	y += FONTH * 2;
	if (vmenu) {
		int bh = y + m.menusel * step;
		blendbox(
		    x - FONTH, bh - 10, x + w + FONTH, bh + FONTH + 10, false);
	}
	for (int j = 0; j < mdisp; j++) {
		draw_text(m.items[j].text, x, y, 2);
		y += step;
	}
	return true;
}

void
newmenu(OFString *name)
{
	if (menus == nil)
		menus = [[OFMutableArray alloc] init];

	[menus addObject:[Menu menuWithName:name]];
}

COMMAND(newmenu, ARG_1STR, ^(OFString *name) {
	newmenu(name);
})

void
menumanual(int m, int n, OFString *text)
{
	if (n == 0)
		[menus[m].items removeAllObjects];

	MenuItem *item = [MenuItem itemWithText:text action:@""];
	[menus[m].items addObject:item];
}

COMMAND(menuitem, ARG_2STR, ^(OFString *text, OFString *action) {
	Menu *menu = menus.lastObject;

	MenuItem *item =
	    [MenuItem itemWithText:text
	                    action:(action.length > 0 ? action : text)];
	[menu.items addObject:item];
})

bool
menukey(int code, bool isdown)
{
	if (vmenu <= 0)
		return false;

	int menusel = menus[vmenu].menusel;
	if (isdown) {
		if (code == SDLK_ESCAPE) {
			menuset(-1);

			if (menuStack.count > 0) {
				menuset(menuStack.lastObject.intValue);
				[menuStack removeLastObject];
			}

			return true;
		} else if (code == SDLK_UP || code == -4)
			menusel--;
		else if (code == SDLK_DOWN || code == -5)
			menusel++;
		int n = menus[vmenu].items.count;
		if (menusel < 0)
			menusel = n - 1;
		else if (menusel >= n)
			menusel = 0;
		menus[vmenu].menusel = menusel;
	} else {
		if (code == SDLK_RETURN || code == -2) {
			OFString *action = menus[vmenu].items[menusel].action;
			if (vmenu == 1)
				connects(getservername(menusel));

			if (menuStack == nil)
				menuStack = [[OFMutableArray alloc] init];

			[menuStack addObject:@(vmenu)];
			menuset(-1);

			execute(action, true);
		}
	}

	return true;
}
