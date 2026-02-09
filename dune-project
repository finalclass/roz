(lang dune 3.17)

(name roz)

(generate_opam_files true)

(pin
 (url "git+https://github.com/tmattio/mosaic.git")
 (package (name mosaic)))

(pin
 (url "git+https://github.com/tmattio/mosaic.git")
 (package (name matrix)))

(pin
 (url "git+https://github.com/tmattio/mosaic.git")
 (package (name toffee)))

(package
 (name roz)
 (synopsis "CLI tool for managing development workflow across Gitea and GitHub")
 (depends
  (ocaml (>= 5.4))
  (cmdliner (>= 1.3.0))
  yojson
  otoml
  mosaic))
