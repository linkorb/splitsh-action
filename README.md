# [Splitsh Lite](https://github.com/splitsh/lite) for Github Actions

A Github Action that allows you to split your monorepo into multiple repositories using [splitsh lite](https://github.com/splitsh/lite).

> This is a fork of [claudiodekker/splitsh-action](https://github.com/claudiodekker/splitsh-action) with a fix for the Git authentication credential storage.

## Usage

1. Create a new file in your repository at `.github/workflows/split.yml`

2. Copy the following content into the `split.yml` file:

   ```yaml
   name: 'Split monorepo'
   
   on:
     push:
       tags:
         - 'v*'

   jobs:
     split:
       runs-on: ubuntu-latest
   
       strategy:
         fail-fast: false
         matrix:
           package: [ 'package-one', 'package-two' ]
   
       steps:
         - name: Checkout monorepo
           uses: actions/checkout@v7
           with:
             fetch-depth: 0
             ref: 'main'
             persist-credentials: false # THIS MUST BE FALSE: These repo credentials will be overridden by the splitter's credentials.   
              
         - name: Split package ${{ matrix.package }}
           uses: "linkorb/splitsh-action@v1.2.1"
           env:
             GITHUB_TOKEN: ${{ secrets.MONOREPO_SPLITTER_PERSONAL_ACCESS_TOKEN }}
           with:
             prefix: "packages/${{ matrix.package }}"
             remote: "https://github.com/your-username/subsplit-of-${{ matrix.package }}.git"
             reference: "${{ github.ref_name }}"
             as_tag: "${{ startsWith(github.ref, 'refs/tags/') }}"
   ```

3. Modify the `matrix`'s `package` property to reflect your to-be-split packages (above: `package-one` and `package-two`).

4. Modify the `prefix` property to reflect the path to your package in your monorepo. In the above example, the packages are located in a `packages/` directory.

5. Modify the `remote` property to reflect the URL of the repository you want to split your package into. In the above example, the packages are split to `https://github.com/your-username/subsplit-of-package-one.git` and `https://github.com/your-username/subsplit-of-package-two.git`.

6. Add a `MONOREPO_SPLITTER_PERSONAL_ACCESS_TOKEN` to your repository's secrets. See the notice about GitHub PAT below. 
   If your monorepo's package directory contains a `.github/workflows/` folder, you'll likely need to add the `workflow` scope to the token as well, as otherwise the splitter cannot push the changes to your repository.

7. Commit and push the file to your (monorepo) repository.

Once done, the GitHub Action will automatically split your monorepo into the target repositories when a commit is added to the provided branches (in the above example, `master`, `1.x`, `2.x` etc.), or when a new tag (e.g. `v1.0.0`) is added to the repository.

## GitHub Personal Access Token

This action uses a GitHub Personal Access Token (PAT) to push changes to the target repositories.

It is recommended to use a fine-grained PAT with the following characteristics:

[Create a new PAT](https://github.com/settings/personal-access-tokens/new) as:

### Fine-grained PAT

**Token name**:
Any meaningful name for this token.

**Expiration:**
The lifetime of the token. It is recommended to rotate this token periodically.

**Resource owner:**
The same user account or the GitHub organization that owns the target repositories.

**Repository access:**

Select `Only selected repositories`, then select the repositories you want to split. GitHub limits the number of repositories to 50.
If you want to split more repositories, either select `All repositories` or create a new Classic PAT.

**Permissions:**

 - `Contents: read and write`
 - `Metadata: read-only` (this will be automatically selected)
 - `Workflows: read and write`: **Only** if your monorepo's sub package directory contains a
   `.github/workflows/` folder. For majority of use cases, this is not required.


### Classic PAT

**Token name**:
Any meaningful name for this token.

**Expiration:**
The lifetime of the token. It is recommended to rotate this token periodically.

**Scopes:**

 - `repo`
 - `workflow`: **Only** if your monorepo's sub package directory contains a `.github/workflows/` folder.

## Using the Docker image

If you want to run the splitter directly, you can use the Docker image:

```bash
docker run --rm \
  -e GITHUB_TOKEN="your_personal_access_token_here" \
  -e GITHUB_WORKSPACE="/workspace" \
  -v "$(pwd):/workspace" \
  ghcr.io/linkorb/splitsh-action:latest \
  "packages/package-one" \
  "https://github.com/your-username/subsplit-of-package-one.git" \
  "main" \
  "false"
```

 - `--rm`: Cleans up and removes the container immediately after it finishes running.
 - `-e GITHUB_TOKEN="...":` Passes your required authentication token into the container's environment.
 - `-e GITHUB_WORKSPACE="/workspace"`: Sets the workspace environment variable that your script expects.
 - `-v "$(pwd):/workspace"`: Mounts your current working directory (which should be the root of your Git repository) into the container at `/workspace`.
 - `ghcr.io/linkorb/splitsh-action:latest`: The Docker image to use.
 - `https://github.com/your-username/subsplit-of-package-one.git`: The remote repository to split your package into.
 - `main`: the branch name or the tag name to split your package into.
 - `false`: (or `"true"`): Whether the reference should be a tag instead of a branch.

## `git push --dry-run`

If you want to see what the splitter will do, you can pass the `DRY_RUN` environment variable:

```yaml
         - name: Split package ${{ matrix.package }}
           uses: "linkorb/splitsh-action@v1.2.1"
           env:
             GITHUB_TOKEN: ${{ secrets.MONOREPO_SPLITTER_PERSONAL_ACCESS_TOKEN }}
             DRY_RUN: "true" # as a string.
           with:
             prefix: "packages/${{ matrix.package }}"
             remote: "https://github.com/your-username/subsplit-of-${{ matrix.package }}.git"
             reference: "${{ github.ref_name }}"
             as_tag: "${{ startsWith(github.ref, 'refs/tags/') }}"
```

## Contributing

Please feel free to open a PR or issue if you have any questions or suggestions.

Credits to the original author of the [splitsh-lite](https://github.com/splitsh/lite) project and the
[claudiodekker/splitsh-action](https://github.com/claudiodekker/splitsh-action) that this fork is based on.
