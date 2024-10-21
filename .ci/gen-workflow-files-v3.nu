#!/usr/bin/env nu

use std log

# cd to git root
cd (git rev-parse --show-toplevel)

# check if a subject depends on a potential dependency
def depends [
    subject:string # package to examine
    maybe_dep:string # maybe a dependency of subject
  ] {
  let subject_drv = (nix eval --no-warn-dirty --raw -- $"($subject).drvPath")
  let maybe_dep_drv = (nix eval --no-warn-dirty --raw -- $"($maybe_dep).drvPath")
  log info $"checking if ($subject_drv) depends on ($maybe_dep_drv)"
  
  let stem = $".cache/deps-tracking/($subject_drv | hash sha256)"
  mkdir ".cache/deps-tracking/"

  mut depends_on = false
  if not ( $stem | path exists ) {
    log info $"getting requisites for ($subject_drv)"
    let tmp_file = (mktemp)
    nix-store --query --requisites $subject_drv | save --raw --force $tmp_file
    mv $tmp_file $stem
    log info $"requisites stored under ($stem)"
  }

  $depends_on = (not ( open $stem | find $maybe_dep_drv | is-empty ))
  
  if $depends_on {
    let first = ( [$subject, $maybe_dep] | sort | first )

    # this is a self-dependency, we must ignore it one way to avoid cycles
    if $subject_drv == $maybe_dep_drv and $first == $subject {
      return false
    }
  }

  return $depends_on
}

# get attribute names of the attribute set
def get-attr-names [
    exprs: # nix expressions to get attrNames of
  ] {
  $exprs 
    | par-each {
        |expr| nix eval --json $expr --apply builtins.attrNames 
        | from json 
      } 
    | flatten 
    | uniq 
    | sort
}

def job-id [
  derivation:string,
  ] {
  $derivation 
    | parse '.#{type}.{system}.{name}' 
    | $"($in.system.0)---($in.type.0)---($in.name.0)"
}

# map from nixos system to github runner type
let systems_map = {
  # aarch64-darwin
  # aarch64-linux

  i686-linux: ubuntu-latest,
  x86_64-darwin: macos-13,
  x86_64-linux: ubuntu-latest
}

let categories = [".#packages" ".#devShells" ".#checks"]
let targets = (get-attr-names $categories
  | each {|system| { $system : (
      $categories 
        | par-each {
            |cat| get-attr-names [$"($cat).($system)"] 
            | each { $"($cat).($system).($in)" } 
          } 
        | flatten
    ) } }
  | reduce {|it, acc| $acc | merge $it }
)

mut cachix_workflow = {
  name: "Nix",
  permissions: {contents: write},
  on: {
    pull_request: null,
    push: {branches: [main]}
  },
  jobs: {},
}

mut release_workflow = {
  name: "Release",
  permissions: {contents: write},
  on: { push: {tags: ["v*"]} },
  jobs: {},
}

let runner_setup = [
  {
    uses: "actions/checkout@v4"
  }
  {
    uses: "cachix/install-nix-action@v25",
    with: { nix_path: "nixpkgs=channel:nixos-unstable" }
  }
  {
    uses: "cachix/cachix-action@v14",
    with: {
      name: dlr-ft,
      authToken: "${{ secrets.CACHIX_AUTH_TOKEN }}"
    }
  }
]

for system in ($targets | columns) {
  if ($systems_map | get -i $system | is-empty) {
    log info $"skipping ($system), since there are no GH-Actions runners for it"
    continue
  }

  # lookup the correct runner for $system
  let runs_on = [ ($systems_map | get $system) ]

  # add jobs for all derivations
  let derivations = ($targets | get $system)
  for derivation in $derivations {

    # job_id for GH-Actions
    let id = ( job-id $derivation )

    # name displayed
    let name = ( job-id $derivation )

    # collection of dependencies
    # TODO currently only considers dependencies on the same $system
    let needs = ($derivations
      | filter {|it| $it != $derivation } # filter out self
      | par-each {|it| {
        name: $it, # the other derivation
        # does self depend on $it?
        needed: (depends $derivation $it)
      } }
      | filter {|it| $it.needed}
      | each {|it| job-id $it.name}
      | sort
    )

    mut new_job = {
      name: $"($name)",
      "runs-on": $runs_on,
      needs: $needs,
      steps: ($runner_setup | append [
        {
          name: Build,
          run: $"nix build ($derivation) --print-build-logs"
        }
      ])
    }
    $cachix_workflow.jobs = ($cachix_workflow.jobs | insert $id $new_job )
  }

  let checks = $derivations 
    | filter { $in | str contains $'.#checks.($system)' } 
    | each { job-id $in }

  # add check job
  $cachix_workflow.jobs = ($cachix_workflow.jobs | insert $"($system)---check" {
    name: $"Check on ($system)",
    "runs-on": $runs_on,
    needs: $checks,
    steps: ($runner_setup | append {
      name: Check,
      run: "nix flake check . --print-build-logs"
    })
  })

  # add release job
  $release_workflow.jobs = ($release_workflow.jobs | insert $"($system)---release" {
    name: $"Build release artifacts for ($system)",
    "runs-on": $runs_on,
    steps: ($runner_setup | append [
      {
        name: "Build release",
        run: "nix build .#release-package --print-build-logs"
      }
      {
        name: Release,
        uses: "softprops/action-gh-release@v1",
        with: {
          draft: "${{ contains(github.ref_name, 'rc') }}",
          prerelease: "${{ contains(github.ref_name, 'alpha') || contains(github.ref_name, 'beta') }}",
          files: "result/*"
        }
      }
    ])
  })
}


log info "saving nix-cachix workflow"
$cachix_workflow | to yaml | save --force .github/workflows/nix.yaml
$release_workflow | to yaml | save --force .github/workflows/release.yaml

log info "prettify generated yaml"
nix run nixpkgs#nodePackages.prettier -- -w .github/workflows/
