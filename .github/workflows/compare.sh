main = ${{inputs.main}}
releasing = ${{inputs.releasing}}

if [ "$(git rev-parse $releasing)" != "$(git rev-parse $main)" ];  then 
    echo  "::set-output name=diff::different"
    else 
     exit
    fi
