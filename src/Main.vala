/*
    Copyright (C) 2012 Johan Mattsson

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

using Birdfont;
using Supplement;
	
public static int main (string[] arg) {
	Supplement.Supplement supplement = new Supplement.Supplement ();
	
	supplement.init (arg);
	
	Gtk.init (ref arg);
	MainWindow window = new MainWindow ();
	GtkWindow native_window = new GtkWindow ("birdfont");	
	window.set_native (native_window);
	Gtk.main ();

	return 0;
}

