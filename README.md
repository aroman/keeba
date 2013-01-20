# Keeba: Homework, simplified.

## What is this?
This is a homework management web app for students that can sync 1-directionally with an existing homework portal, such as a school's official one.

Therefore, it can easily integrate into an existing school system because it does not require the replacement of existing homework management software. All you one need do is build a custom adapter module for their school website (see `jbha.coffee`), add water, and *viola* -- your school's crappy custom/PowerSchool/whatever enterprise homework portal is souped up with the latest web goodness.

It is built with node.js/express on the backend, and Backbone/Bootstrap on the frontend. It uses MongoDB (via Mongoose) for persistence.

### DIY-API

Most likely, there is no official API to pull courses and assignments from your school's homework portal. (There wasn't for my school's). So go and build one (I did). Node.js is exceptionally suited for the task of building a little HTML parsing-based HTTP session proxying interface. 

If you've got the module built and plugged-in, Keeba takes care of the rest. And, thanks in no small part to Matthew Mueller's fantastic [cheerio](https://github.com/MatthewMueller/cheerio) library, I could build such an adapter in a mere 300 lines of CoffeeScript! See for yourself in `jbha.coffee`.

## Why?

Because most of the software schools have for letting kids check their homework at school is absolutely crap. It's like 1990's day whenever I have to log on and see what my teachers have posted for a given night.

The problem is building an end-to-end replacement for such software can be a nightmare. You've got to re-train teachers, support it, and convince the school to get on board. So I just side stepped the whole issue and **built Keeba to run on top of my school's existing infrastructure**.

## Who's using it?

Well, I am :) Oh, and the majority of my school's student body. In fact the student body loves it so much that the school administration has actually agreed to cover the hosting costs and give it "official" sanction... not that I needed it ;)

And you can too! Just fork it and make the changes neccessary to integrate it into your school's environment. It runs quite happily on a free Heroku instance.

## Get up and running
 1. Grab the source: `git clone git@github.com:aroman/keeba.git && cd keeba`
 2. Install dependencies: `npm install`
 3. Edit config.coffee file to your liking.
 4. Make sure tests pass (optional): `make test`
 5. Set GIT_REV (optional, used to show the git rev in the app): ``export GIT_REV=`git rev-parse --short HEAD` ``
 6. Start the server `make serve`

Note that just running `coffee server` is probably not what you want,
as it skips `make build` which compiles the CoffeeScript and Handlebars
templates.

### Configuration
Keeba is configured through environment variables (it is designed to run on Heroku) and config.coffee.

See config.coffee for rules about the precedence of env vs config files.

## Documentation
You can view documentation via Jeremy Askenas's excellent [docco](https://github.com/jashkenas/docco) by
running `make docs` and viewing the created `docs` folder with your favorite web browser.

## Coding style
 - 2-space soft tab indents 
 - cuddled conditionals
 - no ASI in JavaScript... always use semicolons
 - leave out parens where possible and practical in CoffeeScript
 - multi-line comments are a no-no
 - explicit > implicit
 - obvious > magic
 - Picard > Kirk

## Project stats (as of 1/19/13)

    Component           Language        LOC
    
    Backend app         CoffeeScript    1122
    Frontend app        JavaScript      1849
    Tests               CoffeeScript    146
    Config files        JSON/DSL        71
    Server templates    Jade            867
    Client templates    Handlebars      251
    Custom stylesheets  CSS             200
    
                        Total:          4506
                        
## License

Keeba is licensed under the terms of the GNU GPL Version 3.
You can find the full text of the license here: http://www.gnu.org/licenses/gpl.txt
