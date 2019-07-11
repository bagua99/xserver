#!/bin/bash

luastr="package.path='../lualib/?.lua;'..package.path;utils=require'utils';;addr=io.open(filePath,'rb');protobuffer=addr:read'*a';addr:close();t={buf=protobuffer};utils.dump_table_2_file(t,savePath)"

trans(){
    local name=$1
    local f=${name}".proto"
    local pbf=${name}".pb"
    local luaf=${name}"_pb.lua"

    # 生成pb文件
    protoc --descriptor_set_out $pbf $f

    #生成lua文件
    local param="filePath=\"${pbf}\";savePath=\"${luaf}\";"
    lua -e "${param}${luastr}"
}

main(){
    rm *.pb
    rm *.lua

    for f in `ls *.proto` 
    do
        echo "处理 ${f}"
        local name=${f%.proto*}
        trans $name
    done
}

main

