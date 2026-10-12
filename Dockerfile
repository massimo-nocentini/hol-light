# syntax=docker/dockerfile:1

# HOL Light on Alpine.
#
# The core library (hol_lib) is compiled ahead of time with
# HOLLIGHT_USE_MODULE=1, so starting the container only links the compiled
# module into the OCaml toplevel instead of parsing and type-checking every
# core source file again. The core proofs are still replayed at start-up:
# OCaml cannot persist a heap, and saving the live process would need a
# checkpointing tool (DMTCP, CRIU, ...), which this image avoids.
#
#   docker build -t hol-light .
#   docker run --rm -it hol-light

ARG ALPINE_VERSION=3.24
ARG OCAML_VERSION=5.5.1
ARG CAMLP5_VERSION=8.05.02

# Same path in both stages: the OCaml installation and hol.sh hard-code it.
ARG OPAMROOT=/opt/opam
ARG OPAMSWITCH=hol
ARG HOLLIGHT_DIR=/opt/hol-light

###############################################################################
FROM alpine:${ALPINE_VERSION} AS build

ARG OCAML_VERSION
ARG CAMLP5_VERSION
ARG OPAMROOT
ARG OPAMSWITCH
ARG HOLLIGHT_DIR

ENV OPAMROOT=${OPAMROOT} \
    OPAMSWITCH=${OPAMSWITCH} \
    OPAMYES=1 \
    OPAMCONFIRMLEVEL=unsafe-yes

RUN apk add --no-cache \
      opam bash build-base git curl patch rsync m4 perl diffutils \
      gmp-dev pcre2-dev

RUN opam init --bare --disable-sandboxing --no-setup \
 && opam switch create "${OPAMSWITCH}" "ocaml-base-compiler.${OCAML_VERSION}" \
 && opam pin add --no-action camlp5 "${CAMLP5_VERSION}" \
 && opam install zarith ledit camlp5 \
 && opam clean --all-switches --download-cache --logs --repo-cache

WORKDIR ${HOLLIGHT_DIR}
COPY . .

RUN eval "$(opam env)" \
 && HOLLIGHT_USE_MODULE=1 make \
 && ./UnitTests/basic_tests.native \
 && ./UnitTests/printer_tests.native \
 && ./UnitTests/parser_tests.native \
 && ./UnitTests/records.native \
 && rm -f UnitTests/*.byte UnitTests/*.native UnitTests/*_inlined.* \
 && rm -rf "${OPAMROOT}/${OPAMSWITCH}/.opam-switch/sources" \
           "${OPAMROOT}/${OPAMSWITCH}/.opam-switch/build" \
           "${OPAMROOT}/${OPAMSWITCH}/.opam-switch/backup" \
           "${OPAMROOT}/${OPAMSWITCH}/doc" \
           "${OPAMROOT}/${OPAMSWITCH}/man"

###############################################################################
FROM alpine:${ALPINE_VERSION}

ARG OPAMROOT
ARG OPAMSWITCH
ARG HOLLIGHT_DIR

ARG OCAML_PREFIX=${OPAMROOT}/${OPAMSWITCH}

# The same variables `opam env` would set, so no opam is needed at run time.
ENV OPAM_SWITCH_PREFIX=${OCAML_PREFIX} \
    PATH=${OCAML_PREFIX}/bin:${PATH} \
    CAML_LD_LIBRARY_PATH=${OCAML_PREFIX}/lib/stublibs:${OCAML_PREFIX}/lib/ocaml/stublibs:${OCAML_PREFIX}/lib/ocaml \
    OCAML_TOPLEVEL_PATH=${OCAML_PREFIX}/lib/toplevel \
    HOLLIGHT_DIR=${HOLLIGHT_DIR}

RUN apk add --no-cache bash gmp pcre2 \
 && adduser -D -h /home/hol hol

COPY --from=build ${OCAML_PREFIX} ${OCAML_PREFIX}
COPY --from=build ${HOLLIGHT_DIR} ${HOLLIGHT_DIR}

USER hol
WORKDIR /home/hol

ENTRYPOINT ["/opt/hol-light/hol.sh"]
