import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'Building a Personal AI Cloud',
  tagline: 'From Laptop to Production Kubernetes',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://68thandMaine.github.io',
  baseUrl: '/hermes-on-aws-guide/',

  organizationName: '68thandMaine',
  projectName: 'hermes-on-aws-guide',

  onBrokenLinks: 'throw',
  markdown: {
    format: 'detect',
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  themes: ['@docusaurus/theme-mermaid'],

  plugins: [
    [
      require.resolve('@easyops-cn/docusaurus-search-local'),
      {
        hashed: true,
        indexDocs: true,
        docsRouteBasePath: '/',
      },
    ],
  ],

  presets: [
    [
      'classic',
      {
        docs: {
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          numberPrefixParser: false,
          editUrl:
            'https://github.com/68thandMaine/hermes-on-aws-guide/tree/main/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/social-card.svg',
    colorMode: {
      defaultMode: 'light',
      respectPrefersColorScheme: true,
    },
    docs: {
      sidebar: {
        hideable: true,
        autoCollapseCategories: true,
      },
    },
    navbar: {
      title: 'Personal AI Cloud',
      logo: {
        alt: 'Personal AI Cloud',
        src: 'img/logo.svg',
      },
      items: [
        {
          to: '/',
          label: 'Guides',
          position: 'left',
          className: 'guides-top-header',
        },
        {
          href: 'https://github.com/68thandMaine/hermes-on-aws-guide',
          label: 'GitHub',
          position: 'right',
        },
        {
          type: 'search',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Book',
          items: [
            {
              label: 'Table of Contents',
              to: '/',
            },
            {
              label: 'Contributing',
              href: 'https://github.com/68thandMaine/hermes-on-aws-guide/blob/main/CONTRIBUTING.md',
            },
          ],
        },
        {
          title: 'Author',
          items: [
            {
              label: 'Christopher Rudnicky',
              href: 'https://github.com/crudnicky',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Christopher Rudnicky. MIT License.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'yaml', 'json', 'hcl', 'docker'],
    },
    mermaid: {
      theme: {light: 'neutral', dark: 'dark'},
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
