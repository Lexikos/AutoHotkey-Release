
class GitHub
{
    class Context
    {
        __new(owner, repo, token)
        {
            this.owner := owner
            this.repo := repo
            this.token := token
        }
        
        Request(method, url, payload:="", headers:="")
        {
            url := StrReplace(url, ":owner", this.owner)
            url := StrReplace(url, ":repo", this.repo)
            if SubStr(url,1,1) = "/"
                url := "https://api.github.com" url
            req := ComObjCreate("Msxml2.XMLHTTP")
            req.open(method, url, true)
            req.setRequestHeader("Authorization", "token " this.token)
            for k,v in headers {
                req.setRequestHeader(k,v)
            }
            req.send(payload)
            while req.readyState != 4
                sleep 100
            return req
        }
    }
    
    class Release
    {
        ; new Release(context
        ;  , {tag_name, name=tag_name, body, draft=false, prerelease=false})
        __new(context, opt)
        {
            tag_name := opt.tag_name
            name := opt.name!="" ? opt.name : tag_name
            body := opt.body
            body := RegExReplace(body, "[""\\]", "\$0")
            body := RegExReplace(body, "\R", "\n")
            body := RegExReplace(body, "\t", "\t")
            draft := opt.draft ? "true" : "false"
            prerelease := opt.prerelease ? "true" : "false"
            payload =
            (LTrim
              {
                "tag_name": "%tag_name%",
                "name": "%name%",
                "body": "%body%",
                "draft": %draft%,
                "prerelease": %prerelease%
              }
            )
            
            req := context.Request("POST", "/repos/:owner/:repo/releases", payload)
            if (req.statusText != "Created")
            {
                if InStr(req.responseText, "JSON")
                    throw Exception("Bad release payload", -1, release)
                else
                    throw Exception("Error creating release; status " req.statusText, -1, req.responseText)
            }
            JSON_parse_into(req.responseText, this)
            this.context := context
        }
        
        ; Query for an existing (non-draft) release with the given tag
        FromTag(context, tag)
        {
            try {
                req := context.Request("GET", "/repos/:owner/:repo/releases/tags/" tag)
                if (req.statusText != "OK")
                    throw 1
            }
            catch
                return
            
            this := {base: this}
            JSON_parse_into(req.responseText, this)
            this.context := context
            return this
        }
        
        AddAsset(name, filename)
        {
            /* ; This could be used to replace an existing asset
            Loop % this.assets.length
                if this.assets[A_Index-1].name = name
                {
                    this.context.Request("DELETE", "/repos/:owner/:repo/releases/assets/"
                        . this.assets[A_Index-1].id)
                    break
                }
            */
            
            upload_url := RegExReplace(this.upload_url, "\{\?[^\}]*\bname\b[^\}]*\}"
                , "?name=" name, count)
            if !count
                throw Exception("Bad upload_url", -1, this.upload_url)
            
            bytes := FileReadBytes(filename)
            
            D("! Uploading " name " (" bytes.MaxIndex()+1 " bytes)")
            req := this.context.Request("POST", upload_url, bytes
                        , {"Content-Type": ContentType(filename)})
            if (req.statusText != "Created")
                throw Exception("Failed to upload asset", -1, req.status " " req.statusText "`n" req.responseText)
            
            return JSON_parse_into(req.responseText, {})
        }
    }
}

ContentType(filename) {
    SplitPath % filename,,, ext
    return (ext = "zip") ? "application/zip" : "application/octet-stream"
}

FileReadBytes(filename) {
    stream := ComObjCreate("ADODB.Stream")
    stream.Type := 1 ; adTypeBinary
    stream.Open()
    stream.LoadFromFile(filename)
    return stream.Read()  ; Returns an array of bytes.
}

; Lazy JSON parser : requires AutoHotkey 32-bit or Lib\ActiveScript.ahk 
JSON_parse_into(json, obj) {
    static js
    if !js {
        if ActiveScript
            js := new ActiveScript("JScript")
        else
            js := ComObjCreate("ScriptControl"), js.Language := "JScript"
        js.Eval("function parseinto(s,o) { e=eval('0,'+s); for (k in e) o[k]=e[k]; return o}")
    }
    if ComObjType(js)
        return js.Run("parseinto", json, obj)
    else
        return js.parseinto(json, obj)
}
#Include *i <ActiveScript>
