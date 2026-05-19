import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      name: 'home',
      component: () => import('../views/Home.vue'),
    },
    {
      path: '/analyze/:username',
      name: 'analyzing',
      component: () => import('../views/Analyzing.vue'),
      props: true,
    },
    {
      path: '/result/:id',
      name: 'result',
      component: () => import('../views/Result.vue'),
      props: true,
    },
    {
      path: '/leaderboard',
      name: 'leaderboard',
      component: () => import('../views/Leaderboard.vue'),
    },
  ],
})

export default router
