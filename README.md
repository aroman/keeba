# Keeba

  Homework, simplified.

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

## Configuration
Keeba is configured through environment variables (it is designed to run on Heroku) and config.coffee.

See config.coffee for rules about the precedence of env vs config files.

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