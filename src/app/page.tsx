"use client";

import { useState } from 'react';
import styles from './page.module.css';

export default function Home() {
  const [isLoading, setIsLoading] = useState(false);
  const [formData, setFormData] = useState({
    childName: '',
    todayEvent: '',
    favoriteCharacter: ''
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.childName || !formData.todayEvent || !formData.favoriteCharacter) {
      alert("모든 정보를 입력해주세요!");
      return;
    }
    setIsLoading(true);
    // Loading transition state handling could go here.
    // For demo purposes, we just keep it in the loading state.
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData(prev => ({ ...prev, [e.target.name]: e.target.value }));
  };

  return (
    <main className={styles.container}>
      <div className={styles.stars}></div>
      
      {!isLoading ? (
        <div className={styles.content}>
          <h1 className={styles.title}>
            달콤한 <span>꿈나라</span> 여행
          </h1>
          
          <form className={styles.card} onSubmit={handleSubmit}>
            <div className={styles.formGroup}>
              <label className={styles.label} htmlFor="childName">아이 이름</label>
              <input
                id="childName"
                name="childName"
                type="text"
                className={styles.input}
                placeholder="예: 지우"
                value={formData.childName}
                onChange={handleChange}
                required
              />
            </div>

            <div className={styles.formGroup}>
              <label className={styles.label} htmlFor="todayEvent">오늘 있었던 일</label>
              <input
                id="todayEvent"
                name="todayEvent"
                type="text"
                className={styles.input}
                placeholder="예: 치과에 다녀왔어요"
                value={formData.todayEvent}
                onChange={handleChange}
                required
              />
            </div>

            <div className={styles.formGroup}>
              <label className={styles.label} htmlFor="favoriteCharacter">좋아하는 캐릭터</label>
              <input
                id="favoriteCharacter"
                name="favoriteCharacter"
                type="text"
                className={styles.input}
                placeholder="예: 곰돌이, 토끼"
                value={formData.favoriteCharacter}
                onChange={handleChange}
                required
              />
            </div>

            <button type="submit" className={styles.button}>
              ✨ 마법 동화책 만들기
            </button>
          </form>
        </div>
      ) : (
        <div className={styles.content}>
          <div className={styles.loadingContainer}>
            <div className={styles.characterWrapper}>
              <div className={styles.characterBg}></div>
              <div className={styles.character}>🐰</div>
              <div className={styles.sparkles}>
                <span className={styles.sparkle1}>✨</span>
                <span className={styles.sparkle2}>⭐</span>
                <span className={styles.sparkle3}>✨</span>
              </div>
            </div>
            <p className={styles.loadingText}>별빛 가루로 이야기를 짓는 중...</p>
          </div>
        </div>
      )}
    </main>
  );
}
