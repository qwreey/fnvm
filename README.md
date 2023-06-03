# What is fnvm?

fnvm is hack that makes nvm much faster in cygwin.  
In cygwin, nvm makes bash slower. even it takes 2~10 second to initialize  
fnvm using ~/.nvmrc.cached which created by user, containing cached node version.  
and set PATH directly without nvm's version resolver which is very slow due to checking system installed nodejs and iojs, resolving all of installed nodes.  

It also includes auto version changing when change cwd  

![](images/using_fnvm.png)

# Installation

If nvm is not installed, install nvm first
```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
```

Next, install fnvm
```
git clone https://github.com/qwreey75/fnvm.git ~/.nvm/fnvm --depth 1
source ~/.nvm/fnvm/fnvm.sh; fnvm_update
```

Done!

# Configure



[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


# How much fast is?



