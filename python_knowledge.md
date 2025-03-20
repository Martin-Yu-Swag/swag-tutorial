### ENV `PYTHONPATH`

add additional import source directory

eg. in swag project: `./libs`

!!! in vscode, pylance setup:

```json
{
    "python.analysis.extraPaths": [
        "./libs"
    ]
}
```

### Swag convention

登入過程：

- `/login/<string:backend>`
  - social login
  - 建立 token，回傳 refresh token

- `/auth/tokens` / `/refresh`
  - auth endpoint `generate_access_token`
