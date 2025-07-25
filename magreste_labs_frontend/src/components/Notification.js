// src/components/Notification.js
import React from 'react';
import { CheckCircle, AlertCircle } from 'lucide-react';

const Notification = ({ notification }) => {
  if (!notification) return null;

  return (
    <div className={`fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg flex items-center gap-2 max-w-md ${
      notification.type === 'success' 
        ? 'bg-green-500 text-white' 
        : 'bg-red-500 text-white'
    } animate-in slide-in-from-top-2 fade-in-0 duration-300`}>
      {notification.type === 'success' ? (
        <CheckCircle className="w-5 h-5 flex-shrink-0" />
      ) : (
        <AlertCircle className="w-5 h-5 flex-shrink-0" />
      )}
      <span className="text-sm font-medium">{notification.message}</span>
    </div>
  );
};

export default Notification;