/*  tsp.d - a multithreading implementation of the traveling salesman problem
    Copyright (C) 2012 Nathan M. Swan
    
    See README for details.

    tsp.d is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    tsp.d is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
 */
module tsp;

import std.algorithm;
import std.array;
import std.concurrency;
import std.conv;
import std.exception;
import std.functional;
import std.math;
import std.stdio;

void main(string[] args) {
    try {
        enforce(args.length == 2, "must give city file");
        immutable(City)[] cities = cast(immutable(City)[])readFromFile(args[1]);
        auto route = cast(Route)bestRouteBetween(cities[0], cities[0], 
                                                 cities[1 .. $]);
        writeln("Distance: ", route.distance);
        foreach(city; route.cities) {
            writeln(city.name);
        }
    } catch (Exception e) {
        stderr.writeln("Error: ", e.msg);
    }
}

City[] readFromFile(string fname) {
    City[] r;
    foreach(line; File(fname, "r").byLine()) {
        // get rid of comments
        line = findSplit(line, "#")[0];
        
        // put into three tokens
        auto tkrange = splitter(line, " ");
        string[] tokens = filterEmpties(tkrange);
        
        if (tokens.length == 0) continue;
        
        // construct city
        enforce(tokens.length == 3, "must be three tokens per line");
        City c = new City();
        c.name = tokens[0];
        c.x = to!real(tokens[1]);
        c.y = to!real(tokens[2]);
        r ~= c;
    }
    return r;
}

real min = real.max;

// return the best route between the two cities containing the others
immutable(Route) bestRouteBetweenFunc(immutable(City) a,
                                      immutable(City) b, 
                                      immutable(City)[] others)
{
    if (others.length) {
        immutable(Route) best = new immutable(Route)([], real.max);
        foreach(i, o; others) {
            spawn(&brtWrapper, thisTid, b, i, o, others);
        }
        foreach(i; 0 .. others.length) {
            immutable(Route) r = receiveOnly!(immutable(Route))();
            auto realdist = r.distance + distanceBetween(a, o);
            if (realdist < best.distance) {
                best = new immutable(Route)(a ~ r.cities, realdist);
            }
        }
        return best;
    } else {
        return new Route([a, b], distanceBetween(a, b));
    }
}

// calls the bestRouteBetween function and notifies
void brtWrapper(Tid parent,                 // thread to alert of being done
                immutable(City) b,          // the last chain member
                size_t i,                   // index of o
                immutable(City) o,          // o, the focused chain member
                immutable(City)[] others)   // the non-b chain members
{
    auto r = bestRouteBetween(o, b, others[0..i] ~ others[(i+1)..$]);
    parent.send(r);
}

real distanceBetweenFunc(immutable(City) a, immutable(City) b) {
    real xs = a.x - b.x;
    real ys = a.y - b.y;
    return sqrt(xs*xs + ys*ys);
}


string[] filterEmpties(T)(T range) {
    string[] r;
    foreach(str; range) {
        if (!str.empty) {
            r ~= str.idup;
        }
    }
    return r;
}

class City {
    string name;
    real x;
    real y;
}

class Route {
    this(immutable(City)[] c, real d) { cities = c; distance = d; }
    
    immutable(City)[] cities;
    real distance;
}

alias memoize!bestRouteBetweenFunc bestRouteBetween;
alias memoize!distanceBetweenFunc distanceBetween;
