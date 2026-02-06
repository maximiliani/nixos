{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  full = osConfig.local.full;
in
{
  home.packages = [ pkgs.nixfmt-rfc-style ];
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    vimdiffAlias = true;
    vimAlias = true;
    viAlias = true;

    #set colorscheme
    colorschemes.gruvbox = {
      enable = true;
      settings = {
        contrasrDark = "soft";
        improvedStrings = true;
        improvedWarnings = true;
        trueColor = true;
      };
    };

    diagnostic.settings.update_in_insert = true;

    globals = {
      mapleader = ",";
      maplocalleader = " ";
      #for vimtex
      vimtex_view_general_viewer = "okular";
      vimtex_view_general_options = "--unique file:@pdf\#src:@line@tex";

      # for custom build and run commands
      dir = "%:p:h";
      folder = "%:p:h:t";
      file = "%:t";
    };

    #clipboard support
    clipboard = {
      register = "unnamedplus";
      providers.wl-copy.enable = full;
    };

    opts = {
      compatible = false; # disable compatibility to old-time vi
      showmatch = true; # show matching
      ignorecase = true; # case insensitive
      mouse = "a"; # enable mouse for all modes
      hlsearch = true; # highlight search
      incsearch = true; # incremental search
      tabstop = 4; # how wide tab character should be displayed
      softtabstop = 0; # how wide pressing tab should span (replicate tabstop)
      shiftwidth = 0; # how wide shift commands should be (replicate tabstop)
      expandtab = true; # converts tabs to white space
      shiftround = true; # round indentation to multiples shiftwidth
      autoindent = true; # indent a new line the same amount as the line just typed
      smartindent = true; # make smart indentation (after { and so on)
      number = true; # add line numbers
      cursorline = true; # highlight current cursorline
      ttyfast = true; # Speed up scrolling in Vim
      ve = "onemore"; # allow cursor to be at first empty space after line
      encoding = "utf8";
      updatetime = 200;
      spell = true;
      spelllang = "en";
    };
    autoCmd = [
      {
        #change indentation for .nix files
        event = [
          "BufEnter"
          "BufWinEnter"
        ];
        pattern = "*.nix"; # set tabstop of 2 for nix files
        # Or use `vimCallback` with a vimscript function name
        # Or use `command` if you want to run a normal vimscript command
        command = "setlocal tabstop=2";
      }

    ];

    keymaps = [
      #mode = "": for normal,visual,select,operator-pending modes (map)
      #mode = "n": for normal mode
      #mode = "i": for insert mode

      # set window navigation keys
      {
        mode = "";
        key = "<c-j>";
        action = "<c-w>j";
      }
      {
        mode = "";
        key = "<c-k>";
        action = "<c-w>k";
      }
      {
        mode = "";
        key = "<c-l>";
        action = "<c-w>l";
      }
      {
        mode = "";
        key = "<c-h>";
        action = "<c-w>h";
      }

      #for luasnips
      {
        mode = [
          ""
          "i"
        ];
        key = "<c-w>";
        action = "<cmd>lua require('luasnip').jump(1)<Cr>";
        options.silent = true;
      }
      {
        mode = [
          ""
          "i"
        ];
        key = "<c-b>";
        action = "<cmd>lua require('luasnip').jump(-1)<Cr>";
        options.silent = true;
      }
      {
        mode = [
          "i"
        ];
        key = "<c-u>";
        action = "<C-O>:update<CR>";
      }
      {
        mode = [
          ""
          "i"
        ];
        key = "<c-n>";
        action = "luasnip#choice_active() ? '<Plug>luasnip-next-choice'";
        options.silent = true;
      }

      #telescope
      {
        mode = "";
        key = "<LocalLeader>t";
        action = ":Telescope file_browser<CR>";
      }
    ];

    plugins = {
      #improved highlighting
      treesitter = {
        enable = true;
        settings.disabledLanguages = [ "latex" ];
      };

      #shows indentation levels and variable scopes (treesitter)
      indent-blankline.enable = true;

      #automatically creates pairs of brackets, etc.
      nvim-autopairs = {
        enable = true;
        settings = {
          check_ts = true;

        };
        luaConfig.post = ''
          local npairs = require'nvim-autopairs'
          local Rule = require("nvim-autopairs.rule")
          local ts_conds = require('nvim-autopairs.ts-conds')
          local log = require('nvim-autopairs._log')
          local utils = require('nvim-autopairs.utils')

          -- Note that when the cursor is at the end of a comment line,
          -- treesitter thinks we are in attrset_expression
          -- because the cursor is "after" the comment, even though it is on the same line.
          local is_not_ts_node_comment_one_back = function()
              return function(info)
                  log.debug('not_in_ts_node_comment_one_back')

                  local p = vim.api.nvim_win_get_cursor(0)
                  -- Subtract one to account for 1-based row indexing in nvim_win_get_cursor
                  -- Also subtract one from the position of the column to see if we are at the end of a comment.
                  local pos_adjusted = {p[1] - 1, p[2] - 1}

                  vim.treesitter.get_parser():parse()
                  local target = vim.treesitter.get_node({ pos = pos_adjusted, ignore_injections = false })
                  log.debug(target:type())
                  if target ~= nil and utils.is_in_table({'comment'}, target:type()) then
                      return false
                  end

                  local rest_of_line = info.line:sub(info.col)
                  return rest_of_line:match('^%s*$') ~= nil
              end
          end

          npairs.add_rule(
            Rule("= ", ";", "nix")
              :with_pair(is_not_ts_node_comment_one_back())
              :set_end_pair_length(1)
          )
        '';
      };

      #LaTeX support
      vimtex.enable = full;

      # Typst support
      typst-vim.enable = true;
      typst-preview.enable = true;

      #file browser/switcher
      telescope = {
        enable = true;
        settings.defaults = {
          initial_mode = "normal";
          mappings.n = {
            "l" = "select_default";
          };
        };
        extensions.file-browser = {
          enable = true;
          settings.mappings = {
            "n" = {
              "h" = "goto_parent_dir";
            };
          };
        };
      };

      #theme for status bar at bottom
      lualine = {
        enable = true;
        settings.theme = lib.mkDefault "gruvbox";
      };

      #snippet engine
      luasnip = {
        enable = true;
        fromVscode = [
          {
            include = [
              "bash"
              "c"
              "cpp"
              "python"
              "nix"
              "latex"
            ];
          }
        ];
      };

      # Originaly auto enable by telescope
      web-devicons.enable = true;

      #error highlighting and autocomplete (different language servers + luasnip config)
      lsp = {
        enable = true;
        servers = {
          bashls.enable = true; # lsp server for Bash
          # clangd.enable = full; # lsp server for C/C++
          pyright.enable = full; # lsp server for Python
          nil_ls = {
            enable = true; # lsp server for nix
            settings = {
              formatting.command = [ "nixfmt" ];
              nix = {
                flake.autoEvalInputs = true;
                maxMemoryMB = 12884;
              };
            };
          };
          texlab.enable = full; # lsp Server for LaTeX
          typst_lsp = {
            enable = true;
            package = pkgs.tinymist;
          };
        };

        keymaps.lspBuf = {
          "gd" = "definition";
          "gD" = "references";
          "gt" = "type_definition";
          "gi" = "implementation";
          "K" = "hover";
          "<c-s>" = "signature_help";
        };
        #       keymaps = [
        #         {
        #           key = "<c-s>";
        #           lspBufAction = "signature_help";
        #         }
        #         {
        #           mode = "n";
        #           key = "gO";
        #           lspBufAction = "document_symbol";
        #         }
        #       ];
      };
      cmp = {
        enable = true;
        settings = {
          snippet.expand = "luasnip";
          sources = [
            { name = "nvim_lsp"; }
            { name = "luasnip"; } # For luasnip users.
            { name = "path"; }
            { name = "buffer"; }
            { name = "spell"; }
            { name = "dictionary"; }
          ];
          mapping = {
            "<CR>" = "cmp.mapping.confirm()";
            "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
          };
        };
      };
    };
    #collection of default snippets
    extraPlugins = with pkgs.vimPlugins; [
      friendly-snippets
    ];

  };
}
