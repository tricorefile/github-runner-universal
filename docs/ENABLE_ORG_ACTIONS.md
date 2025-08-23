# 启用组织 GitHub Actions

## 检查和启用 Actions

### 1. 访问组织设置
访问：`https://github.com/organizations/tricorelife-labs/settings/profile`

### 2. 启用 Actions（如果未启用）

1. 在左侧菜单找到 **"Actions"** → **"General"**
   - 如果看不到，说明 Actions 可能被禁用
   
2. 如果 Actions 被禁用，访问：
   `https://github.com/organizations/tricorelife-labs/settings/actions`
   
3. 选择 Actions 权限：
   - **Allow all actions and reusable workflows** - 允许所有 actions
   - **Allow tricorelife-labs actions and reusable workflows** - 只允许组织内的 actions
   - **Allow select actions and reusable workflows** - 选择特定的 actions

### 3. 配置 Runner 权限

在 Actions 设置页面：

1. **Actions permissions** - 设置哪些仓库可以使用 Actions
2. **Workflow permissions** - 设置默认的 GITHUB_TOKEN 权限
3. **Runners** - 查看和管理 self-hosted runners

### 4. 查看 Runners

成功启用后，访问：
`https://github.com/organizations/tricorelife-labs/settings/actions/runners`

你应该能看到已注册的 Runner。

## 如果仍然看不到 Actions 选项

可能的原因：

1. **账户类型**：确认 `tricorelife-labs` 确实是组织账户
   - 组织账户 URL：`https://github.com/tricorelife-labs`
   - 个人账户 URL：`https://github.com/tricorelife-labs`（相同，但设置页面不同）

2. **权限不足**：需要组织 Owner 权限
   - 检查你的角色：`https://github.com/orgs/tricorelife-labs/people`

3. **GitHub 计划限制**：
   - 免费组织账户也支持 GitHub Actions
   - 但可能有使用分钟数限制

## 验证组织类型

运行以下命令验证账户类型：

```bash
curl -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/orgs/tricorelife-labs
```

如果返回组织信息，说明是组织账户。
如果返回 404，说明可能是个人账户。

## 组织 Runner 正确配置

如果确认是组织账户，使用以下配置：

```bash
# .env 文件
GITHUB_TOKEN=your_token_with_admin_org_scope
GITHUB_OWNER=tricorelife-labs
RUNNER_SCOPE=org
# 不设置 GITHUB_REPOSITORY
```

然后重启 Runner：

```bash
docker compose down
docker compose up -d
```